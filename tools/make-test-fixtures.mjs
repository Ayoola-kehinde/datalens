/**
 * Generates fixtures for the document-ingestion tests.
 *
 * Why this exists: the PDF text extractor in index.html reads FlateDecode
 * streams, so testing it against a hand-typed string proves nothing. This
 * emits a genuinely compressed PDF with real cross-reference offsets and a
 * real text layer, which is what the extractor has to cope with in the
 * wild.
 *
 * Run:  node tools/make-test-fixtures.mjs
 * Out:  tools/fixtures/sample-statement.pdf
 */

import { deflateSync } from "node:zlib";
import { mkdirSync, writeFileSync } from "node:fs";
import path from "node:path";
import { fileURLToPath } from "node:url";

const ROOT = path.dirname(path.dirname(fileURLToPath(import.meta.url)));
const OUT = path.join(ROOT, "tools", "fixtures");

/* A page of IFRS line items laid out the way a real statement reads:
   label in column one, figure in column two. Deliberately mixes
   thousands separators, an accounting negative, a dash-as-zero and a
   parenthetical percentage so the parser is exercised properly. */
const LINES = [
  "Guaranty Trust Holding Plc",
  "Audited Financial Statements for the year ended 31 December 2025",
  "",
  "INCOME STATEMENT",
  "Revenue                                      1,740,250",
  "Operating Expenses                             (410,180)",
  "Profit Before Tax                              1,330,070",
  "Taxation                                       (298,900)",
  "Net Income                                   1,031,170",
  "",
  "Earnings Per Share                                16.40",
  "Dividend Per Share                                 8.50",
  "",
  "BALANCE SHEET",
  "Total Assets                                  6,300,400",
  "Total Equity                                  1,840,900",
  "Total Debt                                      690,100",
  "",
  "CASH FLOW STATEMENT",
  "Net Cash from Operating Activities              574,300",
  "Capital Expenditure                             (210,000)",
];

function escapePdf(s) {
  /* PDF literal strings: escape backslash and both parentheses. */
  return s.replace(/\\/g, "\\\\").replace(/\(/g, "\\(").replace(/\)/g, "\\)");
}

function buildContent() {
  /* Real generators place every run at an absolute position, descend the
     page, and put a whole row inside one BT/ET block with a Tm per run.
     All three details matter: a parser reacting only to Td/T* cannot tell
     "same line" from "next line" without tracking Y, a fixture that resets
     Y to zero hides that, and splitting rows across blocks makes every
     row look like two lines. So the fixture matches the real shape. */
  let out = "";
  let y = 800;
  LINES.forEach((line) => {
    if (!line.trim()) { y -= 15; return; }
    const m = line.match(/^(.*?)(\s{2,})(\S+)$/);
    out += "BT\n/F1 11 Tf\n";
    if (m) {
      const [, label, , value] = m;
      out += `1 0 0 1 50 ${y} Tm\n(${escapePdf(label)}) Tj\n`;
      out += `1 0 0 1 420 ${y} Tm\n(${escapePdf(value)}) Tj\n`;
    } else {
      out += `1 0 0 1 50 ${y} Tm\n(${escapePdf(line)}) Tj\n`;
    }
    out += "ET\n";
    y -= 15;
  });
  return out;
}

function buildPdf() {
  const content = buildContent();
  const compressed = deflateSync(Buffer.from(content, "latin1"));

  const objects = [];
  const add = (body) => {
    objects.push(body);
    return objects.length; // 1-based object number
  };

  const catalogNo = add(null); // placeholder, filled below
  const pagesNo = add(null);
  const pageNo = add(null);
  const fontNo = add("<< /Type /Font /Subtype /Type1 /BaseFont /Helvetica /Encoding /WinAnsiEncoding >>");
  const contentNo = add(
    `<< /Length ${compressed.length} /Filter /FlateDecode >>\nstream\n${compressed.toString("latin1")}\nendstream`
  );

  objects[catalogNo - 1] = `<< /Type /Catalog /Pages ${pagesNo} 0 R >>`;
  objects[pagesNo - 1] = `<< /Type /Pages /Kids [${pageNo} 0 R] /Count 1 >>`;
  objects[pageNo - 1] =
    `<< /Type /Page /Parent ${pagesNo} 0 R /MediaBox [0 0 595 842] ` +
    `/Resources << /Font << /F1 ${fontNo} 0 R >> >> /Contents ${contentNo} 0 R >>`;

  /* Assemble with a correct xref table. Byte offsets must be measured on
     the Latin-1 byte string, not the JS string, or every later offset is
     wrong — which is exactly the kind of bug a fixture should not hide. */
  let pdf = "%PDF-1.4\n%\xE2\xE3\xCF\xD3\n";
  const offsets = [];
  objects.forEach((body, i) => {
    offsets.push(pdf.length);
    pdf += `${i + 1} 0 obj\n${body}\nendobj\n`;
  });

  const xrefStart = pdf.length;
  pdf += `xref\n0 ${objects.length + 1}\n`;
  pdf += "0000000000 65535 f \n";
  offsets.forEach((o) => {
    pdf += String(o).padStart(10, "0") + " 00000 n \n";
  });
  pdf += `trailer\n<< /Size ${objects.length + 1} /Root ${catalogNo} 0 R >>\n`;
  pdf += `startxref\n${xrefStart}\n%%EOF\n`;

  return Buffer.from(pdf, "latin1");
}

mkdirSync(OUT, { recursive: true });
const buf = buildPdf();
writeFileSync(path.join(OUT, "sample-statement.pdf"), buf);

console.log(`fixture -> tools/fixtures/sample-statement.pdf (${buf.length} bytes)`);
console.log(`  content stream : ${LINES.length} lines, Flate compressed`);
console.log(`  uncompressed   : ${buildContent().length} bytes`);