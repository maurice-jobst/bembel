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
