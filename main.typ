#import "@preview/haw-hamburg:0.8.1": bachelor-thesis, declaration-of-independent-processing

// Register abbreviations and glossary
#import "dependencies.typ": make-glossary, print-glossary, register-glossary
#show: make-glossary
// Abbreviations
#import "abbreviations.typ": abbreviations-entry-list
#register-glossary(abbreviations-entry-list)
// Glossary
#import "glossary.typ": glossary-entry-list
#register-glossary(glossary-entry-list)

// Initialize template
#show: bachelor-thesis.with(
  language: "en",
  title-de: "Portierung von RIOT OS auf den RP2350: Eine Untersuchung einer heterogenen Architektur und programmierbarer I/O",
  keywords-de: ("RISC-V", "RIOT OS", "ARM", "Eingebettete Systeme", "Betriebssystem"),
  abstract-de:
[Eine aktuelle Entwicklung in der Welt der eingebetteten Systeme ist das Vorhandensein heterogener Architekturen, die mehrere Prozessortypen auf einem einzigen Chip kombinieren. Der Raspberry Pi RP2350 ist eine solche Architektur, die zwei ARM Cortex M33- und zwei Hazard3 RISC-V-Kerne sowie ein @pio Subsystem kombiniert.
Derzeit werden solche Architekturen in RIOT OS, einem beliebten Betriebssystem für eingebettete Geräte, nicht unterstützt.

Diese Arbeit untersucht die Herausforderungen und Chancen der Portierung von RIOT OS auf den RP2350, wobei der Schwerpunkt auf dem Verständnis der Architektur, der Implementierung der erforderlichen Low-Level-Unterstützung und der Bewertung der Vorteile eines solchen Systems liegt. Dabei ist auch ein Fokus auf die Möglichkeiten die Multi-Core Verarbeitung in eingebetteten Anwendungen bietet.],

  title-en: "Porting RIOT OS to the RP2350: An Exploration of a Heterogeneous
Architecture and Programmable I/O",
  keywords-en: ("RISC-V", "RIOT OS", "ARM", "Embedded Systems", "Operating System"),
  abstract-en:
[A recent development in the field of embedded systems is the emergence of heterogeneous architectures, which combine multiple types of processors on a single chip. The Raspberry Pi RP2350 is one such architecture, combining two ARM Cortex M33 and two Hazard3 RISC-V cores, along with a @pio subsystem.
Currently, RIOT OS, a popular operating system for embedded devices, does not support such architectures.

This thesis, explores the challenges and opportunities involved in porting RIOT OS to the RP2350.
It focuses on understanding the architecture, implementing the necessary low-level support, and evaluating the advantages of such a system, including multicore processing in embedded applications.],
  author: "Tom Hert",
  faculty: "Computer Science and Digital Society",
  study-course: "Bachelor of Science Informatik Technischer Systeme",
  supervisors: ("Prof. Dr. Thomas C. Schmidt", "Prof. Dr. Franz Korf"),
  submission-date: datetime(year: 2026, month: 01, day: 15),
  // Everything inside "before-content" will be automatically injected
  // into the document before the actual content starts.
  before-content: {
    // Print abbreviations
    pagebreak(weak: true)
    heading("Abbreviations", numbering: none)
    print-glossary(
      abbreviations-entry-list,
      disable-back-references: true,
    )
  },
  // Everything inside "after-content" will be automatically injected
  // into the document after the actual content ends.
  after-content: {
    // Print glossary
    pagebreak(weak: true)
    heading("Glossary", numbering: none)
    print-glossary(
      glossary-entry-list,
      disable-back-references: true,
    )

    // Print bibliography
    pagebreak(weak: true)
    bibliography("bibliography.bib", style: "./ieeetran.csl")

    // Declaration of independent processing (comment out to disable)
    declaration-of-independent-processing
  },
)

// Include chapters of thesis
#pagebreak(weak: true)
#include "chapters/01_introduction.typ"
#include "chapters/02_background.typ"
#include "chapters/03_related_work.typ"
#include "chapters/04_analysis_design.typ"
#include "chapters/05_implementation.typ"
#include "chapters/06_evaluation.typ"
#include "chapters/07_conclusion.typ"
#include "chapters/08_outlook.typ"