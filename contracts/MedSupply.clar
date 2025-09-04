(define-constant ERR-NOT-AUTHORIZED (err u100))
(define-constant ERR-INVALID-MEDICINE (err u101))
(define-constant ERR-MEDICINE-EXISTS (err u102))
(define-constant ERR-MEDICINE-NOT-FOUND (err u103))
(define-constant ERR-INVALID-STATUS (err u104))
(define-constant ERR-INVALID-TRANSFER (err u105))
(define-constant ERR-ALREADY-CONSUMED (err u106))
(define-constant ERR-TEMPERATURE-VIOLATION (err u107))
(define-constant ERR-INVALID-TEMPERATURE (err u108))

(define-constant ROLE-MANUFACTURER u1)
(define-constant ROLE-DISTRIBUTOR u2)
(define-constant ROLE-PHARMACY u3)
(define-constant ROLE-PATIENT u4)

(define-constant STATUS-MANUFACTURED u1)
(define-constant STATUS-IN-TRANSIT u2)
(define-constant STATUS-DELIVERED u3)
(define-constant STATUS-DISPENSED u4)
(define-constant STATUS-CONSUMED u5)
(define-constant STATUS-RECALLED u6)

(define-data-var medicine-id-nonce uint u0)
(define-data-var temperature-reading-nonce uint u0)

(define-map medicines
  { medicine-id: uint }
  {
    name: (string-ascii 64),
    manufacturer: principal,
    batch-number: (string-ascii 32),
    manufacturing-date: uint,
    expiry-date: uint,
    current-owner: principal,
    status: uint,
    location: (string-ascii 64),
    is-recalled: bool,
    created-at: uint,
    requires-cold-chain: bool,
    min-temp-celsius: int,
    max-temp-celsius: int,
    temp-compliant: bool
  }
)

(define-map stakeholders
  { user: principal }
  {
    role: uint,
    name: (string-ascii 64),
    verified: bool,
    registered-at: uint
  }
)

(define-map supply-chain-events
  { event-id: uint }
  {
    medicine-id: uint,
    from-owner: principal,
    to-owner: principal,
    status: uint,
    location: (string-ascii 64),
    timestamp: uint,
    notes: (string-ascii 128)
  }
)

(define-data-var event-id-nonce uint u0)

(define-map temperature-readings
  { reading-id: uint }
  {
    medicine-id: uint,
    temperature-celsius: int,
    recorder: principal,
    location: (string-ascii 64),
    timestamp: uint,
    is-compliant: bool
  }
)

(define-public (register-stakeholder (role uint) (name (string-ascii 64)))
  (begin
    (asserts! (and (>= role u1) (<= role u4)) ERR-NOT-AUTHORIZED)
    (map-set stakeholders
      { user: tx-sender }
      {
        role: role,
        name: name,
        verified: true,
        registered-at: stacks-block-height
      }
    )
    (ok true)
  )
)

(define-public (register-medicine 
  (name (string-ascii 64))
  (batch-number (string-ascii 32))
  (manufacturing-date uint)
  (expiry-date uint)
  (location (string-ascii 64))
  (requires-cold-chain bool)
  (min-temp-celsius int)
  (max-temp-celsius int))
  (let ((medicine-id (+ (var-get medicine-id-nonce) u1))
        (stakeholder (map-get? stakeholders { user: tx-sender })))
    (asserts! (is-some stakeholder) ERR-NOT-AUTHORIZED)
    (asserts! (is-eq (get role (unwrap-panic stakeholder)) ROLE-MANUFACTURER) ERR-NOT-AUTHORIZED)
    (asserts! (> expiry-date manufacturing-date) ERR-INVALID-MEDICINE)
    (asserts! (is-none (map-get? medicines { medicine-id: medicine-id })) ERR-MEDICINE-EXISTS)
    (asserts! (or (not requires-cold-chain) (< min-temp-celsius max-temp-celsius)) ERR-INVALID-TEMPERATURE)
    
    (var-set medicine-id-nonce medicine-id)
    
    (map-set medicines
      { medicine-id: medicine-id }
      {
        name: name,
        manufacturer: tx-sender,
        batch-number: batch-number,
        manufacturing-date: manufacturing-date,
        expiry-date: expiry-date,
        current-owner: tx-sender,
        status: STATUS-MANUFACTURED,
        location: location,
        is-recalled: false,
        created-at: stacks-block-height,
        requires-cold-chain: requires-cold-chain,
        min-temp-celsius: min-temp-celsius,
        max-temp-celsius: max-temp-celsius,
        temp-compliant: true
      }
    )
    
    (unwrap-panic (log-supply-chain-event medicine-id tx-sender tx-sender STATUS-MANUFACTURED location "Medicine manufactured"))
    (ok medicine-id)
  )
)

(define-public (transfer-medicine (medicine-id uint) (to-owner principal) (new-location (string-ascii 64)))
  (let ((medicine (map-get? medicines { medicine-id: medicine-id }))
        (current-stakeholder (map-get? stakeholders { user: tx-sender }))
        (target-stakeholder (map-get? stakeholders { user: to-owner })))
    
    (asserts! (is-some medicine) ERR-MEDICINE-NOT-FOUND)
    (asserts! (is-some current-stakeholder) ERR-NOT-AUTHORIZED)
    (asserts! (is-some target-stakeholder) ERR-NOT-AUTHORIZED)
    
    (let ((med-data (unwrap-panic medicine))
          (current-role (get role (unwrap-panic current-stakeholder)))
          (target-role (get role (unwrap-panic target-stakeholder))))
      
      (asserts! (is-eq (get current-owner med-data) tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (not (get is-recalled med-data)) ERR-INVALID-TRANSFER)
      (asserts! (not (is-eq (get status med-data) STATUS-CONSUMED)) ERR-ALREADY-CONSUMED)
      (asserts! (is-valid-transfer current-role target-role) ERR-INVALID-TRANSFER)
      (asserts! (or (not (get requires-cold-chain med-data)) (get temp-compliant med-data)) ERR-TEMPERATURE-VIOLATION)
      
      (let ((new-status (get-transfer-status current-role target-role)))
        (map-set medicines
          { medicine-id: medicine-id }
          (merge med-data {
            current-owner: to-owner,
            status: new-status,
            location: new-location
          })
        )
        
        (unwrap-panic (log-supply-chain-event medicine-id tx-sender to-owner new-status new-location "Medicine transferred"))
        (ok true)
      )
    )
  )
)

(define-public (update-status (medicine-id uint) (new-status uint) (new-location (string-ascii 64)) (notes (string-ascii 128)))
  (let ((medicine (map-get? medicines { medicine-id: medicine-id }))
        (stakeholder (map-get? stakeholders { user: tx-sender })))
    
    (asserts! (is-some medicine) ERR-MEDICINE-NOT-FOUND)
    (asserts! (is-some stakeholder) ERR-NOT-AUTHORIZED)
    (asserts! (and (>= new-status u1) (<= new-status u6)) ERR-INVALID-STATUS)
    
    (let ((med-data (unwrap-panic medicine)))
      (asserts! (is-eq (get current-owner med-data) tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (not (get is-recalled med-data)) ERR-INVALID-TRANSFER)
      
      (map-set medicines
        { medicine-id: medicine-id }
        (merge med-data {
          status: new-status,
          location: new-location
        })
      )
      
      (unwrap-panic (log-supply-chain-event medicine-id tx-sender tx-sender new-status new-location notes))
      (ok true)
    )
  )
)

(define-public (recall-medicine (medicine-id uint) (reason (string-ascii 128)))
  (let ((medicine (map-get? medicines { medicine-id: medicine-id })))
    (asserts! (is-some medicine) ERR-MEDICINE-NOT-FOUND)
    
    (let ((med-data (unwrap-panic medicine)))
      (asserts! (is-eq (get manufacturer med-data) tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (not (get is-recalled med-data)) ERR-INVALID-TRANSFER)
      
      (map-set medicines
        { medicine-id: medicine-id }
        (merge med-data {
          status: STATUS-RECALLED,
          is-recalled: true
        })
      )
      
      (unwrap-panic (log-supply-chain-event medicine-id tx-sender tx-sender STATUS-RECALLED (get location med-data) reason))
      (ok true)
    )
  )
)

(define-public (dispense-medicine (medicine-id uint) (patient principal) (prescription-id (string-ascii 32)))
  (let ((medicine (map-get? medicines { medicine-id: medicine-id }))
        (pharmacy-stakeholder (map-get? stakeholders { user: tx-sender }))
        (patient-stakeholder (map-get? stakeholders { user: patient })))
    
    (asserts! (is-some medicine) ERR-MEDICINE-NOT-FOUND)
    (asserts! (is-some pharmacy-stakeholder) ERR-NOT-AUTHORIZED)
    (asserts! (is-some patient-stakeholder) ERR-NOT-AUTHORIZED)
    
    (let ((med-data (unwrap-panic medicine))
          (pharmacy-role (get role (unwrap-panic pharmacy-stakeholder)))
          (patient-role (get role (unwrap-panic patient-stakeholder))))
      
      (asserts! (is-eq (get current-owner med-data) tx-sender) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq pharmacy-role ROLE-PHARMACY) ERR-NOT-AUTHORIZED)
      (asserts! (is-eq patient-role ROLE-PATIENT) ERR-NOT-AUTHORIZED)
      (asserts! (not (get is-recalled med-data)) ERR-INVALID-TRANSFER)
      (asserts! (> (get expiry-date med-data) stacks-block-height) ERR-INVALID-MEDICINE)
      (asserts! (or (not (get requires-cold-chain med-data)) (get temp-compliant med-data)) ERR-TEMPERATURE-VIOLATION)
      
      (map-set medicines
        { medicine-id: medicine-id }
        (merge med-data {
          current-owner: patient,
          status: STATUS-DISPENSED
        })
      )
      
      (unwrap-panic (log-supply-chain-event medicine-id tx-sender patient STATUS-DISPENSED (get location med-data) 
        (concat "Dispensed with prescription: " prescription-id)))
      (ok true)
    )
  )
)

(define-private (log-supply-chain-event 
  (medicine-id uint) 
  (from-owner principal) 
  (to-owner principal) 
  (status uint) 
  (location (string-ascii 64)) 
  (notes (string-ascii 128)))
  (let ((event-id (+ (var-get event-id-nonce) u1)))
    (var-set event-id-nonce event-id)
    (map-set supply-chain-events
      { event-id: event-id }
      {
        medicine-id: medicine-id,
        from-owner: from-owner,
        to-owner: to-owner,
        status: status,
        location: location,
        timestamp: stacks-block-height,
        notes: notes
      }
    )
    (ok event-id)
  )
)

(define-private (is-valid-transfer (from-role uint) (to-role uint))
  (or
    (and (is-eq from-role ROLE-MANUFACTURER) (is-eq to-role ROLE-DISTRIBUTOR))
    (and (is-eq from-role ROLE-DISTRIBUTOR) (is-eq to-role ROLE-PHARMACY))
    (and (is-eq from-role ROLE-DISTRIBUTOR) (is-eq to-role ROLE-DISTRIBUTOR))
    (and (is-eq from-role ROLE-PHARMACY) (is-eq to-role ROLE-PATIENT))
  )
)

(define-private (get-transfer-status (from-role uint) (to-role uint))
  (if (and (is-eq from-role ROLE-MANUFACTURER) (is-eq to-role ROLE-DISTRIBUTOR))
    STATUS-IN-TRANSIT
    (if (and (is-eq from-role ROLE-DISTRIBUTOR) (is-eq to-role ROLE-PHARMACY))
      STATUS-DELIVERED
      (if (and (is-eq from-role ROLE-PHARMACY) (is-eq to-role ROLE-PATIENT))
        STATUS-DISPENSED
        STATUS-IN-TRANSIT
      )
    )
  )
)

(define-public (record-temperature (medicine-id uint) (temperature-celsius int) (location (string-ascii 64)))
  (let ((medicine (map-get? medicines { medicine-id: medicine-id }))
        (stakeholder (map-get? stakeholders { user: tx-sender }))
        (reading-id (+ (var-get temperature-reading-nonce) u1)))
    
    (asserts! (is-some medicine) ERR-MEDICINE-NOT-FOUND)
    (asserts! (is-some stakeholder) ERR-NOT-AUTHORIZED)
    
    (let ((med-data (unwrap-panic medicine)))
      (asserts! (get requires-cold-chain med-data) ERR-INVALID-MEDICINE)
      (asserts! (is-eq (get current-owner med-data) tx-sender) ERR-NOT-AUTHORIZED)
      
      (let ((is-temp-compliant (and 
                                 (>= temperature-celsius (get min-temp-celsius med-data))
                                 (<= temperature-celsius (get max-temp-celsius med-data))))
            (updated-compliance (and (get temp-compliant med-data) is-temp-compliant)))
        
        (var-set temperature-reading-nonce reading-id)
        
        (map-set temperature-readings
          { reading-id: reading-id }
          {
            medicine-id: medicine-id,
            temperature-celsius: temperature-celsius,
            recorder: tx-sender,
            location: location,
            timestamp: stacks-block-height,
            is-compliant: is-temp-compliant
          }
        )
        
        (map-set medicines
          { medicine-id: medicine-id }
          (merge med-data {
            temp-compliant: updated-compliance
          })
        )
        
        (ok reading-id)
      )
    )
  )
)

(define-read-only (get-medicine (medicine-id uint))
  (map-get? medicines { medicine-id: medicine-id })
)

(define-read-only (get-stakeholder (user principal))
  (map-get? stakeholders { user: user })
)

(define-read-only (get-supply-chain-event (event-id uint))
  (map-get? supply-chain-events { event-id: event-id })
)

(define-read-only (get-medicine-count)
  (var-get medicine-id-nonce)
)

(define-read-only (get-event-count)
  (var-get event-id-nonce)
)

(define-read-only (verify-authenticity (medicine-id uint))
  (match (map-get? medicines { medicine-id: medicine-id })
    medicine-data
    (ok {
      authentic: true,
      manufacturer: (get manufacturer medicine-data),
      batch-number: (get batch-number medicine-data),
      manufacturing-date: (get manufacturing-date medicine-data),
      expiry-date: (get expiry-date medicine-data),
      is-recalled: (get is-recalled medicine-data),
      current-status: (get status medicine-data)
    })
    ERR-MEDICINE-NOT-FOUND
  )
)

(define-read-only (is-medicine-valid (medicine-id uint))
  (match (map-get? medicines { medicine-id: medicine-id })
    medicine-data
    (and
      (not (get is-recalled medicine-data))
      (> (get expiry-date medicine-data) stacks-block-height)
      (not (is-eq (get status medicine-data) STATUS-CONSUMED))
      (or (not (get requires-cold-chain medicine-data)) (get temp-compliant medicine-data))
    )
    false
  )
)

(define-read-only (get-temperature-reading (reading-id uint))
  (map-get? temperature-readings { reading-id: reading-id })
)

(define-read-only (get-temperature-reading-count)
  (var-get temperature-reading-nonce)
)

(define-read-only (check-cold-chain-compliance (medicine-id uint))
  (match (map-get? medicines { medicine-id: medicine-id })
    medicine-data
    (ok {
      requires-cold-chain: (get requires-cold-chain medicine-data),
      min-temp-celsius: (get min-temp-celsius medicine-data),
      max-temp-celsius: (get max-temp-celsius medicine-data),
      temp-compliant: (get temp-compliant medicine-data)
    })
    ERR-MEDICINE-NOT-FOUND
  )
)
