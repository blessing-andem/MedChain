# MedChain Protocol

**Decentralized Healthcare Data Marketplace on Bitcoin L2 (Stacks)**

MedChain Protocol establishes a privacy-preserving and trustless marketplace where patients can monetize their medical data while researchers gain verifiable access to high-quality health information. Built on **Stacks**, with Bitcoin as the ultimate settlement layer, MedChain enforces immutable consent, transparent pricing, and automated royalty distribution through smart contracts.

---

## System Overview

Healthcare data today is siloed, inaccessible, and often monetized without patient consent. MedChain solves this by:

* Empowering **patients** to register and monetize medical data.
* Allowing **researchers** to request, purchase, and verify anonymized datasets for IRB-approved studies.
* Enforcing **consent management**, ensuring patients control when and how their data is used.
* Distributing payments transparently between patients (80%) and the platform (20%).
* Maintaining **audit trails** and **quality assessments** for compliance and trust.

The protocol enables a secure, incentive-aligned marketplace for healthcare research while ensuring compliance with **HIPAA-aligned** privacy standards.

---

## Contract Architecture

The contract is implemented in **Clarity**, the smart contract language of Stacks.

### **Core Components**

* **Patient Data Management**

  * Patients register encrypted medical data (EHR, lab results, imaging, genomic, wearable, lifestyle).
  * Data is listed only after quality assessment.
  * Ownership and provenance secured on-chain.

* **Consent Management**

  * Patients grant or revoke consent at the **data-type** level.
  * Supports consent boundaries: research purpose, geographic restriction, re-identification permissions.
  * Automatic expiration (1-year default).

* **Research Requests**

  * Researchers create funded data requests with IRB approval references.
  * Requests specify required data types, minimum quality, pricing, and maximum records.
  * Escrowed budget ensures guaranteed payment upon purchase.

* **Data Transactions**

  * Researchers purchase available patient records.
  * Automated split: **80% to patient, 20% to platform**.
  * Usage logged for audit trail.

* **Quality Assurance**

  * Owner or designated assessors rate data completeness, accuracy, timeliness, and consistency.
  * Final score determines marketplace eligibility.

* **Profiles & Reputation**

  * **Patients**: Track earnings, consent preferences, data availability.
  * **Researchers**: Track purchases, budget spent, reputation, and completed studies.

---

## Data Flow

**1. Patient Onboarding**

* Patient grants consent → Uploads encrypted data → Registers data record.

**2. Data Verification**

* Contract owner (or authorized assessor) evaluates quality → Marks data available if above threshold.

**3. Research Request**

* Researcher submits project details → Allocates budget in STX → Contract escrows funds.

**4. Purchase Flow**

* Researcher selects records → Contract validates consent, quality, and budget → Executes payment split → Logs usage.

**5. Settlement & Audit**

* Patient earnings updated → Platform revenue updated → Data usage stored immutably for compliance.

---

## Key Features

* ✅ **Bitcoin-Secured Provenance** — all ownership records anchored to Bitcoin via Stacks.
* ✅ **Granular Consent** — patients retain full control, with expiration and revocation.
* ✅ **Dynamic Pricing** — supports market-driven pricing and scarcity-based value.
* ✅ **Quality Assurance** — IRB-compliant scoring mechanisms ensure research validity.
* ✅ **Transparent Economics** — royalty distribution and audit logs visible on-chain.
* ✅ **HIPAA Alignment** — built-in anonymization, auditability, and temporal access.

---

## Smart Contract Modules

| Module                   | Purpose                                                              |
| ------------------------ | -------------------------------------------------------------------- |
| **Patient Data Records** | Manages medical data listings, ownership, quality scores.            |
| **Consent Management**   | Records patient consent, restrictions, and revocations.              |
| **Research Requests**    | Allows researchers to submit projects with budget allocation.        |
| **Transactions**         | Handles payments, platform fees, and usage logging.                  |
| **Quality Assessments**  | Stores quality metrics and controls data availability.               |
| **Profiles**             | Tracks patient and researcher activity, reputation, and preferences. |

---

## Platform Governance

* **Emergency Pause**: Global kill-switch for halting protocol operations in case of security or compliance breaches.
* **Assessors**: Currently restricted to contract owner (can be extended for decentralized assessor roles).
* **Fee Structure**: Fixed at 20% platform fee, adjustable via contract upgrade proposals.

---

## Deployment Notes

* Written in **Clarity** for the Stacks blockchain.
* Integrates with **Stacks’ PoX** mechanism for Bitcoin anchoring.
* Requires off-chain storage for encrypted medical data; only hashes stored on-chain.
* Must integrate with external **KYC/IRB verification oracles** for compliance.

---

## Example Use Cases

* A **pharma company** requests genomic data for drug discovery.
* A **public health researcher** requests lifestyle data for population studies.
* A **wearable company** shares anonymized fitness data to study heart disease.
