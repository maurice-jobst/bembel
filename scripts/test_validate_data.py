#!/usr/bin/env python3
"""Tests for the curated-data validator. Stdlib unittest — same no-pip rule as
the validator itself, so CI runs it in the same job.

These exist because a validation rule nobody has watched fail is a comment
(LESSONS §E4). Each test takes a valid dataset and breaks exactly one thing.
"""

import copy
import unittest
from pathlib import Path

import validate_data as v
import verify_sources

RINGS = {"06412000": "frankfurt", "06434011": "kernraum"}


def valid_dataset() -> dict:
    return {
        "version": 1,
        "id": "fountains",
        "type": "FeatureCollection",
        "generator": "scripts/generate_fountains.py",
        "features": [
            {
                "type": "Feature",
                "id": "ffm-hauptwache",
                "geometry": {"type": "Point", "coordinates": [8.6797, 50.1136]},
                "properties": {
                    "name": "Brunnen an der Hauptwache",
                    "ags": "06412000",
                    "ring": "frankfurt",
                    "updated": "2026-08-14",
                    "sources": ["https://offenedaten.frankfurt.de/dataset/brunnen"],
                    "kind": "stadt",
                    "seasonal": True,
                },
            }
        ],
    }


class GeoJSONValidatorTests(unittest.TestCase):
    def setUp(self) -> None:
        v.errors.clear()

    def check(self, doc) -> list[str]:
        v.check_geojson(doc, "test.geojson", RINGS)
        return list(v.errors)

    def broken(self, mutate) -> list[str]:
        doc = valid_dataset()
        mutate(doc["features"][0])
        return self.check(doc)

    def assertRejected(self, problems: list[str], needle: str) -> None:
        self.assertTrue(problems, "expected a rejection, got none")
        joined = "\n".join(problems)
        self.assertIn(needle, joined)

    def test_valid_dataset_passes(self):
        self.assertEqual(self.check(valid_dataset()), [])

    # --- the three acceptance criteria on the ticket ------------------------

    def test_missing_ags_is_rejected(self):
        self.assertRejected(self.broken(lambda f: f["properties"].pop("ags")), "'ags' must be 8 digits")

    def test_unknown_ring_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(ring="wetterau")), "'ring' must be one of"
        )

    def test_empty_sources_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(sources=[])), "must carry a non-empty 'sources'"
        )

    def test_source_without_url_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(sources=["Stadt Frankfurt, telefonisch"])),
            "must be an http(s) URL",
        )

    # --- and the ones the schema alone could not express --------------------

    def test_ags_outside_the_region_model_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(ags="11000000")), "is not in rings.json"
        )

    def test_ring_contradicting_rings_json_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(ring="rheinmain")), "contradicts rings.json"
        )

    def test_swapped_latitude_and_longitude_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["geometry"].update(coordinates=[50.1136, 8.6797])),
            "outside Rhein-Main",
        )

    def test_prose_property_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(note="Ein Satz.\nUnd noch einer.")),
            "facts only",
        )

    def test_overlong_string_property_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(note="x" * 301)),
            "facts only",
        )

    def test_nested_object_property_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(operator={"name": "Mainova"})),
            "facts only",
        )

    def test_duplicate_feature_ids_are_rejected(self):
        doc = valid_dataset()
        doc["features"].append(copy.deepcopy(doc["features"][0]))
        self.assertRejected(self.check(doc), "duplicate id")

    def test_non_point_geometry_is_rejected(self):
        self.assertRejected(
            self.broken(
                lambda f: f.update(
                    geometry={"type": "LineString", "coordinates": [[8.6, 50.1], [8.7, 50.2]]}
                )
            ),
            "geometry type must be 'Point'",
        )

    def test_boolean_coordinates_are_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["geometry"].update(coordinates=[True, 50.1])),
            "must be [longitude, latitude]",
        )

    def test_impossible_date_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(updated="2026-02-31")), "not a real date"
        )

    def test_non_iso_date_is_rejected(self):
        self.assertRejected(
            self.broken(lambda f: f["properties"].update(updated="14.08.2026")), "must be a YYYY-MM-DD"
        )

    def test_empty_feature_collection_is_rejected(self):
        doc = valid_dataset()
        doc["features"] = []
        self.assertRejected(self.check(doc), "non-empty list")

    def test_wrong_collection_type_is_rejected(self):
        doc = valid_dataset()
        doc["type"] = "Feature"
        self.assertRejected(self.check(doc), "must be 'FeatureCollection'")

    def test_a_broken_rings_table_does_not_blame_every_feature(self):
        """rings.json failing its own check must not produce one bogus
        cross-reference error per feature on top of it."""
        v.check_geojson(valid_dataset(), "test.geojson", {})
        self.assertEqual(list(v.errors), [])


def valid_registry() -> dict:
    return {
        "version": 1,
        "updated": "2026-08-16",
        "tiers": {"1": "load-bearing", "2": "keyless", "3": "key", "4": "static", "5": "no API"},
        "sources": [
            {
                "id": "ffm_baustellen",
                "name": "Frankfurt verkehrsrelevante Baustellen",
                "tier": 1,
                "protocol": "wfs",
                "base": "https://geowebdienste.frankfurt.de/Baustellen",
                "layers": [{"typename": "opendata_verkehr:Baustellen", "observed": {"count": 270}}],
                "auth": "none",
                "license": "dl-de/by-2-0",
                "verified_at": "2026-08-16",
                "gotchas": ["endevent 2099-12-31 means permanent change, not a bug."],
            },
            {
                "id": "rmv_hapi",
                "name": "RMV Open Data HAFAS API",
                "tier": 3,
                "portal": "https://opendata.rmv.de",
                "auth": "free API key, requested by form",
                "verified_at": "2026-08-16",
            },
            {
                "id": "fes_abfallkalender",
                "name": "FES Abfallkalender",
                "tier": 5,
                "searched_at": "2026-08-16",
                "finding": "fes-frankfurt.de/api/abfallkalender returns 404. No documented API.",
            },
        ],
        "deprecated": [
            {
                "id": "ffm_ckan_legacy",
                "url": "https://offenedaten.frankfurt.de/api/3/action/package_list",
                "status": "HTTP 404 (Tomcat). Portal migrated to a JS frontend.",
                "verified_at": "2026-08-16",
                "replacement": ["ffm_baustellen"],
            }
        ],
    }


class SourceRegistryTests(unittest.TestCase):
    """data/sources.json. The interesting rules are the ones a JSON Schema
    cannot state: a tier is a claim about what access costs, so an entry can be
    field-by-field well-formed and still contradict itself."""

    def setUp(self) -> None:
        v.errors.clear()

    def check(self, doc) -> list[str]:
        v.check_sources(doc, "sources.json")
        return list(v.errors)

    def broken(self, index, mutate) -> list[str]:
        doc = valid_registry()
        mutate(doc["sources"][index])
        return self.check(doc)

    def assertRejected(self, problems: list[str], needle: str) -> None:
        self.assertTrue(problems, "expected a rejection, got none")
        self.assertIn(needle, "\n".join(problems))

    def test_valid_registry_passes(self):
        self.assertEqual(self.check(valid_registry()), [])

    # --- tier is a claim, and the entry has to keep it ----------------------

    def test_keyless_tier_carrying_auth_is_rejected(self):
        self.assertRejected(
            self.broken(0, lambda s: s.update(auth="API key by email")), "means keyless by definition"
        )

    def test_key_tier_claiming_no_auth_is_rejected(self):
        self.assertRejected(self.broken(1, lambda s: s.update(auth="none")), "must say what it costs")

    def test_tier_five_carrying_an_endpoint_is_rejected(self):
        """The shape that rots invisibly: the verifier skips tier 5, so an
        endpoint parked there is an endpoint nothing ever calls."""
        self.assertRejected(
            self.broken(2, lambda s: s.update(url="https://fes-frankfurt.de/api/abfall")),
            "there is nothing to call",
        )

    def test_tier_five_without_a_finding_is_rejected(self):
        self.assertRejected(self.broken(2, lambda s: s.pop("finding")), "must say what the search turned up")

    def test_live_source_without_a_verification_date_is_rejected(self):
        self.assertRejected(self.broken(0, lambda s: s.pop("verified_at")), "must be a YYYY-MM-DD date")

    def test_impossible_verification_date_is_rejected(self):
        self.assertRejected(self.broken(0, lambda s: s.update(verified_at="2026-02-31")), "not a real date")

    # --- shape ---------------------------------------------------------------

    def test_duplicate_source_ids_are_rejected(self):
        doc = valid_registry()
        doc["sources"].append(copy.deepcopy(doc["sources"][0]))
        self.assertRejected(self.check(doc), "duplicate id")

    def test_unknown_tier_is_rejected(self):
        self.assertRejected(self.broken(0, lambda s: s.update(tier=6)), "'tier' must be 1–5")

    def test_plaintext_endpoint_is_rejected(self):
        self.assertRejected(
            self.broken(0, lambda s: s.update(base="http://geowebdienste.frankfurt.de/Baustellen")),
            "must be an https URL",
        )

    def test_services_as_a_bare_list_is_rejected(self):
        """A list of URLs loses the name each endpoint is referred to by, and
        every consumer then keys off array position."""
        self.assertRejected(
            self.broken(0, lambda s: s.update(services=["https://geowebdienste.frankfurt.de/Rad"])),
            "not a bare list",
        )

    def test_prose_gotcha_is_rejected(self):
        self.assertRejected(
            self.broken(0, lambda s: s.update(gotchas=["Erst dies.\nDann das."])), "one-line strings"
        )

    def test_missing_tier_legend_is_rejected(self):
        doc = valid_registry()
        del doc["tiers"]["5"]
        self.assertRejected(self.check(doc), "tiers 1 through 5")

    def test_replacement_pointing_nowhere_is_rejected(self):
        doc = valid_registry()
        doc["deprecated"][0]["replacement"] = ["ffm_ckan_v2"]
        self.assertRejected(self.check(doc), "is not a source id in this registry")

    def test_deprecated_entry_without_a_reason_is_rejected(self):
        doc = valid_registry()
        doc["deprecated"][0].pop("status")
        self.assertRejected(self.check(doc), "must say why it is dead")


class SourceVerifierCoverageTests(unittest.TestCase):
    """Offline half of the liveness check. Reaching the network is a weekly
    job, but 'is every registered source actually reachable by the verifier'
    is a pure question, so it is answered on every PR. Without this a new
    entry can be added in a shape plan() does not understand and be skipped in
    silence — which is how the incoming registry shipped three unchecked
    entries (LESSONS §E6)."""

    def setUp(self) -> None:
        self.registry = v.load(v.DATA / "sources.json")

    def test_every_reachable_source_has_a_check(self):
        self.assertEqual(verify_sources.coverage_gaps(self.registry), [])

    def test_exempt_tiers_are_not_silently_counted_as_covered(self):
        """The exemption is for tiers with nothing to call, not a way to park
        an entry out of the verifier's reach."""
        registry = {
            "sources": [{"id": "ghost", "name": "Ghost", "tier": 4, "auth": "none"}]
        }
        self.assertEqual(verify_sources.coverage_gaps(registry), ["ghost"])

    def test_a_wfs_layer_plans_a_hits_request(self):
        source = next(s for s in self.registry["sources"] if s["id"] == "ffm_baustellen")
        checks = list(verify_sources.plan(source))
        self.assertEqual(len(checks), 4)
        self.assertTrue(all(c.url.endswith("resultType=hits") for c in checks))
        self.assertEqual(checks[0].observed, {"count": 270})

    def test_a_collapsed_feature_count_is_a_failure_not_a_note(self):
        check = verify_sources.Check("x", "https://example.invalid", "hits", {"count": 270})
        self.assertEqual(verify_sources.drift(check, {"count": 0}), ("was 270 features, now 0", True))

    def test_a_moved_feature_count_is_a_note_not_a_failure(self):
        check = verify_sources.Check("x", "https://example.invalid", "hits", {"count": 270})
        message, fatal = verify_sources.drift(check, {"count": 265})
        self.assertFalse(fatal)
        self.assertIn("270 -> 265", message)

    def test_an_unrecorded_count_does_not_invent_drift(self):
        check = verify_sources.Check("x", "https://example.invalid", "hits", {})
        self.assertEqual(verify_sources.drift(check, {"count": 265}), (None, False))

    def test_only_live_tiers_and_coverage_gaps_are_worth_alerting_on(self):
        """The weekly job's exit code is its alerting decision. Tier 4 is
        vendored at build time and the Frankfurt WFS hosts time out often
        enough that paging on them would train everyone to ignore the page
        (LESSONS §E1). Tier 0 is the uncovered-source sentinel."""
        self.assertEqual(verify_sources.ACTIONABLE_TIERS, {0, 1, 2})
        self.assertNotIn(4, verify_sources.ACTIONABLE_TIERS)

    def test_exempt_and_actionable_tiers_do_not_overlap(self):
        """A tier that is never called cannot also be one we alert on."""
        self.assertEqual(verify_sources.EXEMPT_TIERS & verify_sources.ACTIONABLE_TIERS, set())

    def test_a_jsonp_body_is_unwrapped_before_parsing(self):
        check = verify_sources.Check("x", "https://example.invalid", "jsonp")
        reading, problem = verify_sources.read(check, b'warnWetter.loadWarnings({"time":1});')
        self.assertIsNone(problem)
        self.assertEqual(reading["bytes"], 36)


class RingsIndexTests(unittest.TestCase):
    def test_index_maps_ags_to_ring(self):
        doc = {"municipalities": [{"ags": "06412000", "name": "Frankfurt", "ring": "frankfurt"}]}
        self.assertEqual(v.rings_index(doc), {"06412000": "frankfurt"})

    def test_malformed_rows_are_skipped_not_crashed_on(self):
        doc = {"municipalities": [{"ags": 6412000, "ring": "frankfurt"}, "nonsense", {}]}
        self.assertEqual(v.rings_index(doc), {})

    def test_missing_table_yields_an_empty_index(self):
        self.assertEqual(v.rings_index(None), {})
        self.assertEqual(v.rings_index({}), {})


class RepositoryTests(unittest.TestCase):
    def test_the_real_repository_validates(self):
        """The end-to-end check, so a green unit suite over a red repo is not a
        thing that can happen."""
        v.errors.clear()
        self.assertEqual(v.main(), 0)

    def test_every_schema_file_is_valid_json(self):
        for path in sorted((v.REPO / "data" / "schema").glob("*.json")):
            with self.subTest(schema=path.name):
                self.assertIsInstance(v.load(path), dict, f"{path.name} did not parse")


if __name__ == "__main__":
    unittest.main(verbosity=2)
