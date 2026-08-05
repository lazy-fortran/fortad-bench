#!/usr/bin/env python3
"""Behavioral checks for bibliography matching and PDF admission."""

from pathlib import Path
import tempfile
import unittest

import fetch_literature


class LiteratureTests(unittest.TestCase):
    def test_title_match_rejects_nearest_wrong_work(self):
        wanted = "Efficient and Modular Implicit Differentiation"
        self.assertTrue(fetch_literature.title_matches(wanted, wanted))
        self.assertFalse(fetch_literature.title_matches("A Survey of Numerical Weather Models", wanted))

    def test_bibliography_contains_the_curated_entries(self):
        entries = fetch_literature.parse_bib()
        keys = {entry["_key"] for entry in entries}
        self.assertEqual(len(entries), 33)
        self.assertIn("hascoet2013tapenade", keys)
        self.assertIn("blondel2022implicit", keys)

    def test_download_accepts_pdf_and_rejects_html(self):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            pdf = root / "source.pdf"
            html = root / "source.html"
            pdf.write_bytes(b"%PDF-1.7\nfixture\n")
            html.write_text("<html>not a PDF</html>\n")
            self.assertTrue(fetch_literature.download(pdf.as_uri(), root / "accepted.pdf"))
            self.assertFalse(fetch_literature.download(html.as_uri(), root / "rejected.pdf"))
            self.assertTrue((root / "accepted.pdf").exists())
            self.assertFalse((root / "rejected.pdf").exists())


if __name__ == "__main__":
    unittest.main()
