;; Title: MedChain Protocol
;; 
;; Summary: Decentralized Healthcare Data Marketplace on Bitcoin L2
;; 
;; Description:
;; MedChain Protocol creates a trustless, privacy-preserving marketplace where patients
;; monetize their medical data while researchers gain access to high-quality health information.
;; Built on Stacks' Bitcoin settlement layer, the protocol ensures immutable consent management,
;; transparent pricing discovery, and automated royalty distribution through smart contracts.
;; 
;; The protocol implements comprehensive privacy controls with multi-tiered anonymization,
;; temporal consent boundaries, and cryptographic data verification. Quality assurance mechanisms
;; ensure data integrity while IRB-compliant research request workflows maintain ethical standards.
;; 
;; Key Features:
;; - Bitcoin-secured data provenance and ownership verification
;; - Dynamic pricing mechanisms based on data quality and scarcity
;; - Granular consent management with automatic expiration
;; - Multi-stakeholder reputation systems for trust establishment
;; - Transparent fee distribution (80% patient, 20% platform)
;; - HIPAA-aligned privacy frameworks with on-chain audit trails

;; CONSTANTS - Error Codes

(define-constant contract-owner tx-sender)

(define-constant err-owner-only (err u100))
(define-constant err-not-found (err u101))
(define-constant err-unauthorized (err u102))
(define-constant err-invalid-amount (err u103))
(define-constant err-insufficient-balance (err u104))
(define-constant err-already-exists (err u105))
(define-constant err-invalid-data (err u106))
(define-constant err-consent-required (err u107))
(define-constant err-data-expired (err u108))
(define-constant err-quality-too-low (err u109))

;; CONSTANTS - Platform Configuration

(define-constant platform-fee-bp u2000)      ;; 20% platform fee (2000 basis points)
(define-constant min-data-quality u60)       ;; Minimum 60% quality score required
(define-constant consent-duration u52560)    ;; 1 year in blocks (~10min blocks)
(define-constant min-payment u10000000)      ;; 10 STX minimum payment threshold

;; CONSTANTS - Data Type Definitions

(define-constant data-type-ehr u1)           ;; Electronic Health Records
(define-constant data-type-lab u2)           ;; Laboratory Results
(define-constant data-type-imaging u3)       ;; Medical Imaging
(define-constant data-type-genomic u4)       ;; Genomic Data
(define-constant data-type-wearable u5)      ;; Wearable Device Data
(define-constant data-type-lifestyle u6)     ;; Lifestyle & Wellness Data

;; DATA VARIABLES - Global State

(define-data-var data-record-counter uint u0)
(define-data-var research-request-counter uint u0)
(define-data-var total-payments-distributed uint u0)
(define-data-var platform-revenue uint u0)
(define-data-var emergency-pause bool false)

;; DATA MAPS - Patient Data Records

(define-map patient-data-records
    uint ;; record-id
    {
        patient: principal,
        data-type: uint,
        data-hash: (buff 32),     ;; SHA-256 hash of encrypted data
        quality-score: uint,      ;; 0-100 quality score
        price: uint,              ;; Price in microSTX
        is-available: bool,
        created-at: uint,
        consent-expires: uint,
        usage-count: uint,
        total-earned: uint,
        metadata: (string-ascii 256) ;; JSON metadata string
    }
)

;; DATA MAPS - Consent Management

(define-map patient-consents
    { patient: principal, data-type: uint }
    {
        granted: bool,
        granted-at: uint,
        expires-at: uint,
        research-purposes: (list 10 (string-ascii 64)),
        geographic-restrictions: (list 5 (string-ascii 32)),
        can-reidentify: bool
    }
)

;; DATA MAPS - Research Requests

(define-map research-requests
    uint ;; request-id
    {
        researcher: principal,
        title: (string-ascii 128),
        description: (string-ascii 512),
        data-types-needed: (list 6 uint),
        max-price-per-record: uint,
        min-quality: uint,
        max-records: uint,
        purpose: (string-ascii 256),
        institution: (string-ascii 128),
        irb-approval: (string-ascii 64),   ;; IRB approval number
        created-at: uint,
        expires-at: uint,
        status: uint,                      ;; 1=active, 2=completed, 3=cancelled
        budget-allocated: uint,
        records-purchased: uint
    }
)

;; DATA MAPS - Usage Tracking

(define-map data-usage-log
    { record-id: uint, request-id: uint }
    {
        researcher: principal,
        patient: principal,
        purchased-at: uint,
        price-paid: uint,
        usage-type: (string-ascii 64),
        anonymization-level: uint ;; 1=basic, 2=advanced, 3=differential-privacy
    }
)

;; DATA MAPS - Patient Profiles

(define-map patient-profiles
    principal
    {
        total-records: uint,
        total-earnings: uint,
        quality-rating: uint,             ;; Average quality score
        data-types-available: (list 6 uint),
        consent-preferences: uint,        ;; Bitmask of consent preferences
        kyc-verified: bool,
        last-activity: uint,
        privacy-level: uint               ;; 1=low, 2=medium, 3=high, 4=maximum
    }
)

;; DATA MAPS - Researcher Profiles

(define-map researcher-profiles
    principal
    {
        institution: (string-ascii 128),
        research-areas: (list 10 (string-ascii 64)),
        total-purchases: uint,
        total-spent: uint,
        reputation-score: uint,           ;; 0-100 reputation score
        verified: bool,
        active-requests: uint,
        completed-studies: uint
    }
)

;; DATA MAPS - Quality Verification

(define-map quality-assessments
    uint ;; record-id
    {
        assessor: principal,
        completeness: uint,               ;; 0-100 score
        accuracy: uint,                   ;; 0-100 score
        timeliness: uint,                 ;; 0-100 score
        consistency: uint,                ;; 0-100 score
        final-score: uint,                ;; 0-100 aggregated score
        assessed-at: uint,
        notes: (string-ascii 256)
    }
)

;; PUBLIC FUNCTIONS - Patient Data Management

;; Register patient data record for marketplace listing
;; @param data-type: Type of medical data (EHR, lab, imaging, etc.)
;; @param data-hash: SHA-256 hash of encrypted data
;; @param price: Asking price in microSTX
;; @param metadata: JSON metadata string describing the data
;; @returns: (ok record-id) on success
(define-public (register-patient-data
    (data-type uint)
    (data-hash (buff 32))
    (price uint)
    (metadata (string-ascii 256)))
    (let (
        (record-id (+ (var-get data-record-counter) u1))
        (caller tx-sender)
        (consent (map-get? patient-consents { patient: caller, data-type: data-type }))
    )
        (asserts! (not (var-get emergency-pause)) (err u999))
        (asserts! (>= price min-payment) err-invalid-amount)
        (asserts! (<= data-type data-type-lifestyle) err-invalid-data)
        
        ;; Verify active consent exists
        (asserts! 
            (match consent
                consent-record (and 
                    (get granted consent-record)
                    (< stacks-block-height (get expires-at consent-record)))
                false
            )
            err-consent-required
        )
        
        ;; Create data record
        (map-set patient-data-records record-id {
            patient: caller,
            data-type: data-type,
            data-hash: data-hash,
            quality-score: u0,
            price: price,
            is-available: false,
            created-at: stacks-block-height,
            consent-expires: (+ stacks-block-height consent-duration),
            usage-count: u0,
            total-earned: u0,
            metadata: metadata
        })
        
        ;; Update patient profile
        (let (
            (profile (default-to 
                { total-records: u0, total-earnings: u0, quality-rating: u0, 
                  data-types-available: (list), consent-preferences: u0, kyc-verified: false, 
                  last-activity: u0, privacy-level: u2 }
                (map-get? patient-profiles caller)))
        )
            (map-set patient-profiles caller 
                (merge profile {
                    total-records: (+ (get total-records profile) u1),
                    last-activity: stacks-block-height
                })
            )
        )
        
        (var-set data-record-counter record-id)
        (ok record-id)
    )
)

;; PUBLIC FUNCTIONS - Consent Management

;; Grant consent for specific data type usage
;; @param data-type: Type of medical data being consented
;; @param research-purposes: List of approved research purposes
;; @param geographic-restrictions: List of approved geographic regions
;; @param can-reidentify: Whether re-identification is permitted
;; @returns: (ok expires-at) timestamp when consent expires
(define-public (grant-consent
    (data-type uint)
    (research-purposes (list 10 (string-ascii 64)))
    (geographic-restrictions (list 5 (string-ascii 32)))
    (can-reidentify bool))
    (let (
        (caller tx-sender)
        (expires-at (+ stacks-block-height consent-duration))
    )
        (asserts! (not (var-get emergency-pause)) (err u999))
        (asserts! (<= data-type data-type-lifestyle) err-invalid-data)
        
        ;; Set consent parameters
        (map-set patient-consents 
            { patient: caller, data-type: data-type }
            {
                granted: true,
                granted-at: stacks-block-height,
                expires-at: expires-at,
                research-purposes: research-purposes,
                geographic-restrictions: geographic-restrictions,
                can-reidentify: can-reidentify
            }
        )
        
        (ok expires-at)
    )
)

;; Revoke consent for specific data type
;; @param data-type: Type of medical data to revoke consent for
;; @returns: (ok true) on successful revocation
(define-public (revoke-consent (data-type uint))
    (let (
        (caller tx-sender)
    )
        (asserts! (not (var-get emergency-pause)) (err u999))
        
        ;; Update consent to revoked
        (match (map-get? patient-consents { patient: caller, data-type: data-type })
            consent-record 
            (begin
                (map-set patient-consents 
                    { patient: caller, data-type: data-type }
                    (merge consent-record {
                        granted: false,
                        expires-at: stacks-block-height
                    })
                )
                (ok true)
            )
            err-not-found
        )
    )
)

;; PUBLIC FUNCTIONS - Research Requests

;; Create research data request with allocated budget
;; @param title: Research project title
;; @param description: Detailed research description
;; @param data-types-needed: List of required data types
;; @param max-price-per-record: Maximum price willing to pay per record
;; @param min-quality: Minimum quality score required
;; @param max-records: Maximum number of records needed
;; @param purpose: Research purpose description
;; @param institution: Research institution name
;; @param irb-approval: IRB approval reference number
;; @param budget: Total budget allocated in microSTX
;; @returns: (ok request-id) on success
(define-public (create-research-request
    (title (string-ascii 128))
    (description (string-ascii 512))
    (data-types-needed (list 6 uint))
    (max-price-per-record uint)
    (min-quality uint)
    (max-records uint)
    (purpose (string-ascii 256))
    (institution (string-ascii 128))
    (irb-approval (string-ascii 64))
    (budget uint))
    (let (
        (request-id (+ (var-get research-request-counter) u1))
        (caller tx-sender)
        (expires-at (+ stacks-block-height (* consent-duration u3)))
    )
        (asserts! (not (var-get emergency-pause)) (err u999))
        (asserts! (>= max-price-per-record min-payment) err-invalid-amount)
        (asserts! (>= min-quality min-data-quality) err-quality-too-low)
        (asserts! (>= budget (* max-records max-price-per-record)) err-insufficient-balance)
        
        ;; Transfer budget to contract escrow
        (try! (stx-transfer? budget caller (as-contract tx-sender)))
        
        ;; Create research request
        (map-set research-requests request-id {
            researcher: caller,
            title: title,
            description: description,
            data-types-needed: data-types-needed,
            max-price-per-record: max-price-per-record,
            min-quality: min-quality,
            max-records: max-records,
            purpose: purpose,
            institution: institution,
            irb-approval: irb-approval,
            created-at: stacks-block-height,
            expires-at: expires-at,
            status: u1,
            budget-allocated: budget,
            records-purchased: u0
        })
        
        ;; Update researcher profile
        (let (
            (profile (default-to
                { institution: "", research-areas: (list), total-purchases: u0, total-spent: u0,
                  reputation-score: u50, verified: false, active-requests: u0, completed-studies: u0 }
                (map-get? researcher-profiles caller)))
        )
            (map-set researcher-profiles caller
                (merge profile {
                    institution: institution,
                    active-requests: (+ (get active-requests profile) u1)
                })
            )
        )
        
        (var-set research-request-counter request-id)
        (ok request-id)
    )
)

;; PUBLIC FUNCTIONS - Data Transactions

;; Purchase data record for research use
;; @param record-id: ID of the data record to purchase
;; @param request-id: ID of the research request
;; @returns: (ok price) paid for the record
(define-public (purchase-data-record (record-id uint) (request-id uint))
    (let (
        (record (unwrap! (map-get? patient-data-records record-id) err-not-found))
        (request (unwrap! (map-get? research-requests request-id) err-not-found))
        (caller tx-sender)
        (price (get price record))
        (platform-fee (/ (* price platform-fee-bp) u10000))
        (patient-payment (- price platform-fee))
    )
        (asserts! (not (var-get emergency-pause)) (err u999))
        (asserts! (is-eq caller (get researcher request)) err-unauthorized)
        (asserts! (is-eq (get status request) u1) err-invalid-data)
        (asserts! (get is-available record) err-invalid-data)
        (asserts! (< (get usage-count record) u10) err-invalid-data)
        (asserts! (>= (get quality-score record) (get min-quality request)) err-quality-too-low)
        (asserts! (<= price (get max-price-per-record request)) err-invalid-amount)
        (asserts! (< (get records-purchased request) (get max-records request)) err-insufficient-balance)
        
        ;; Verify consent validity
        (let (
            (consent (unwrap! 
                (map-get? patient-consents { patient: (get patient record), data-type: (get data-type record) })
                err-consent-required))
        )
            (asserts! (get granted consent) err-consent-required)
            (asserts! (< stacks-block-height (get expires-at consent)) err-data-expired)
        )
        
        ;; Transfer payment to patient
        (try! (as-contract (stx-transfer? patient-payment tx-sender (get patient record))))
        
        ;; Update platform revenue
        (var-set platform-revenue (+ (var-get platform-revenue) platform-fee))
        
        ;; Update record usage statistics
        (map-set patient-data-records record-id
            (merge record {
                usage-count: (+ (get usage-count record) u1),
                total-earned: (+ (get total-earned record) patient-payment)
            })
        )
        
        ;; Update research request progress
        (map-set research-requests request-id
            (merge request {
                records-purchased: (+ (get records-purchased request) u1)
            })
        )
        
        ;; Log data usage for audit trail
        (map-set data-usage-log
            { record-id: record-id, request-id: request-id }
            {
                researcher: caller,
                patient: (get patient record),
                purchased-at: stacks-block-height,
                price-paid: price,
                usage-type: "research-access",
                anonymization-level: u2
            }
        )
        
        ;; Update total payments distributed
        (var-set total-payments-distributed (+ (var-get total-payments-distributed) patient-payment))
        
        (ok price)
    )
)

;; PUBLIC FUNCTIONS - Quality Assurance

;; Assess data quality and approve for marketplace
;; @param record-id: ID of the data record to assess
;; @param completeness: Completeness score (0-100)
;; @param accuracy: Accuracy score (0-100)
;; @param timeliness: Timeliness score (0-100)
;; @param consistency: Consistency score (0-100)
;; @param notes: Quality assessment notes
;; @returns: (ok final-score) calculated quality score
(define-public (assess-data-quality
    (record-id uint)
    (completeness uint)
    (accuracy uint)
    (timeliness uint)
    (consistency uint)
    (notes (string-ascii 256)))
    (let (
        (record (unwrap! (map-get? patient-data-records record-id) err-not-found))
        (caller tx-sender)
        (final-score (/ (+ completeness accuracy timeliness consistency) u4))
    )
        ;; Only contract owner can assess quality (simplified authorization)
        (asserts! (is-eq caller contract-owner) err-unauthorized)
        
        ;; Store quality assessment details
        (map-set quality-assessments record-id {
            assessor: caller,
            completeness: completeness,
            accuracy: accuracy,
            timeliness: timeliness,
            consistency: consistency,
            final-score: final-score,
            assessed-at: stacks-block-height,
            notes: notes
        })
        
        ;; Update record with quality score and availability
        (map-set patient-data-records record-id
            (merge record {
                quality-score: final-score,
                is-available: (>= final-score min-data-quality)
            })
        )
        
        (ok final-score)
    )
)

;; READ-ONLY FUNCTIONS - Data Retrieval

;; Get data record details
;; @param record-id: ID of the data record
;; @returns: (some record) or none
(define-read-only (get-data-record (record-id uint))
    (map-get? patient-data-records record-id)
)

;; Get research request details
;; @param request-id: ID of the research request
;; @returns: (some request) or none
(define-read-only (get-research-request (request-id uint))
    (map-get? research-requests request-id)
)

;; Get patient consent status
;; @param patient: Patient principal
;; @param data-type: Type of medical data
;; @returns: (some consent) or none
(define-read-only (get-consent-status (patient principal) (data-type uint))
    (map-get? patient-consents { patient: patient, data-type: data-type })
)

;; Get patient profile
;; @param patient: Patient principal
;; @returns: (some profile) or none
(define-read-only (get-patient-profile (patient principal))
    (map-get? patient-profiles patient)
)

;; Get researcher profile
;; @param researcher: Researcher principal
;; @returns: (some profile) or none
(define-read-only (get-researcher-profile (researcher principal))
    (map-get? researcher-profiles researcher)
)

;; Get data usage log entry
;; @param record-id: ID of the data record
;; @param request-id: ID of the research request
;; @returns: (some usage-log) or none
(define-read-only (get-usage-log (record-id uint) (request-id uint))
    (map-get? data-usage-log { record-id: record-id, request-id: request-id })
)

;; Get quality assessment
;; @param record-id: ID of the data record
;; @returns: (some assessment) or none
(define-read-only (get-quality-assessment (record-id uint))
    (map-get? quality-assessments record-id)
)

;; READ-ONLY FUNCTIONS - Analytics

;; Get platform statistics
;; @returns: Platform-wide statistics tuple
(define-read-only (get-platform-stats)
    {
        total-records: (var-get data-record-counter),
        total-requests: (var-get research-request-counter),
        total-payments: (var-get total-payments-distributed),
        platform-revenue: (var-get platform-revenue),
        emergency-pause: (var-get emergency-pause)
    }
)

;; Calculate estimated earnings for data contribution
;; @param data-type: Type of medical data
;; @param quality-estimate: Estimated quality score (0-100)
;; @param usage-estimate: Estimated number of uses
;; @returns: Earnings estimation breakdown
(define-read-only (calculate-estimated-earnings 
    (data-type uint) 
    (quality-estimate uint) 
    (usage-estimate uint))
    (let (
        (base-price (if (is-eq data-type data-type-genomic) u50000000
                     (if (is-eq data-type data-type-imaging) u30000000
                     (if (is-eq data-type data-type-ehr) u20000000
                     u10000000))))
        (quality-multiplier (/ quality-estimate u100))
        (estimated-price (* base-price quality-multiplier))
        (platform-fee (/ (* estimated-price platform-fee-bp) u10000))
        (net-earnings (- estimated-price platform-fee))
        (total-potential (* net-earnings usage-estimate))
    )
        {
            estimated-price-per-use: estimated-price,
            net-earnings-per-use: net-earnings,
            total-potential-earnings: total-potential,
            platform-fee-per-use: platform-fee
        }
    )
)