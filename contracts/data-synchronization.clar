;; Data Synchronization Contract
;; Synchronizes customer data across channels

(define-constant CONTRACT_OWNER tx-sender)
(define-constant ERR_UNAUTHORIZED (err u400))
(define-constant ERR_SYNC_JOB_NOT_FOUND (err u401))
(define-constant ERR_INVALID_SYNC_STATUS (err u402))

;; Data structures
(define-map sync-jobs
  { job-id: uint }
  {
    source-channel: uint,
    target-channels: (list 10 uint),
    data-type: (string-ascii 30),
    status: (string-ascii 15),
    created-at: uint,
    completed-at: uint,
    initiated-by: principal
  }
)

(define-map data-records
  { record-id: uint }
  {
    customer-id: (string-ascii 50),
    data-hash: (buff 32),
    data-type: (string-ascii 30),
    source-channel: uint,
    sync-status: (string-ascii 15),
    last-synced: uint
  }
)

(define-data-var next-job-id uint u1)
(define-data-var next-record-id uint u1)

;; Create sync job
(define-public (create-sync-job (source-channel uint) (target-channels (list 10 uint)) (data-type (string-ascii 30)))
  (let ((job-id (var-get next-job-id)))
    (map-set sync-jobs
      { job-id: job-id }
      {
        source-channel: source-channel,
        target-channels: target-channels,
        data-type: data-type,
        status: "pending",
        created-at: block-height,
        completed-at: u0,
        initiated-by: tx-sender
      }
    )
    (var-set next-job-id (+ job-id u1))
    (print { event: "sync-job-created", job-id: job-id, source-channel: source-channel })
    (ok job-id)
  )
)

;; Update sync job status
(define-public (update-sync-status (job-id uint) (new-status (string-ascii 15)))
  (match (map-get? sync-jobs { job-id: job-id })
    job-data
    (begin
      (asserts! (is-eq tx-sender (get initiated-by job-data)) ERR_UNAUTHORIZED)
      (map-set sync-jobs
        { job-id: job-id }
        (merge job-data {
          status: new-status,
          completed-at: (if (is-eq new-status "completed") block-height (get completed-at job-data))
        })
      )
      (print { event: "sync-status-updated", job-id: job-id, status: new-status })
      (ok true)
    )
    ERR_SYNC_JOB_NOT_FOUND
  )
)

;; Add data record for synchronization
(define-public (add-data-record (customer-id (string-ascii 50)) (data-hash (buff 32)) (data-type (string-ascii 30)) (source-channel uint))
  (let ((record-id (var-get next-record-id)))
    (map-set data-records
      { record-id: record-id }
      {
        customer-id: customer-id,
        data-hash: data-hash,
        data-type: data-type,
        source-channel: source-channel,
        sync-status: "pending",
        last-synced: u0
      }
    )
    (var-set next-record-id (+ record-id u1))
    (print { event: "data-record-added", record-id: record-id, customer-id: customer-id })
    (ok record-id)
  )
)

;; Mark data as synced
(define-public (mark-data-synced (record-id uint))
  (match (map-get? data-records { record-id: record-id })
    record-data
    (begin
      (map-set data-records
        { record-id: record-id }
        (merge record-data { sync-status: "synced", last-synced: block-height })
      )
      (print { event: "data-synced", record-id: record-id })
      (ok true)
    )
    ERR_SYNC_JOB_NOT_FOUND
  )
)

;; Get sync job
(define-read-only (get-sync-job (job-id uint))
  (map-get? sync-jobs { job-id: job-id })
)

;; Get data record
(define-read-only (get-data-record (record-id uint))
  (map-get? data-records { record-id: record-id })
)
