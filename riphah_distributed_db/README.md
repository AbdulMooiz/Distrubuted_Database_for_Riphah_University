# Riphah University Distributed Database Prototype

A small, runnable PostgreSQL prototype for the DDBMS group project. It models the Main, Lahore and Faisalabad campuses with three separate PostgreSQL 16 containers and connects them with `postgres_fdw`.

This folder is the working prototype and evidence generator. The assignment's formal D1 design report and D2 presentation are intentionally not included yet.

## Stack

- PostgreSQL 16, one database container per campus
- Docker Compose, one persistent volume per campus
- `postgres_fdw` for cross-campus reads and writes
- SQL seed, verification and demonstration scripts
- PowerShell runner for Windows, plus an optional Makefile

No web UI or API is included because the brief asks for a distributed database design, not an application interface.

## Requirements

- Docker Desktop with Docker Compose v2
- Windows PowerShell, macOS Terminal or Linux shell
- About 1 GB free disk space for the images and database volumes

The demo password is `postgres`. This is only for a local classroom prototype. Do not expose these containers or credentials on a public network.

## Run on Windows PowerShell

Open PowerShell in this folder. If Windows blocks local scripts, run `Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass` in that PowerShell window first. This changes the policy only for the current session.

```powershell
# 1. Start all three campus databases
.\scripts\run.ps1 -Task up

# 2. Seed the synthetic dataset, distribute fragments and refresh query statistics
.\scripts\run.ps1 -Task seed

# 3. Run completeness, disjointness, reconstruction and distribution checks
.\scripts\run.ps1 -Task verify

# 4. Create the student transfer procedure and run the transfer round trip
.\scripts\run.ps1 -Task transfer
```

To build the cluster, seed it, verify it and run the demonstrations for Parts A to F (except the network isolation test), use:

```powershell
.\scripts\run.ps1 -Task all
```

The network failure test is kept separate because it temporarily disconnects the Faisalabad container.

## Run the demonstrations

```powershell
.\scripts\run.ps1 -Task a          # Part A: horizontal and derived fragments
.\scripts\run.ps1 -Task b          # Part B: vertical split and view comparison
.\scripts\run.ps1 -Task c          # Part C: Status fragmentation trap
.\scripts\run.ps1 -Task d          # Part D: allocation and replica update
.\scripts\run.ps1 -Task e          # Part E: Q1 to Q6 and query plans
.\scripts\run.ps1 -Task semijoin   # Part E: semijoin byte comparison
```

Part E includes Q1 at Lahore, Q2 at a Lahore student's home campus, Q3 at a Faisalabad course, Q4 from a local faculty replica, Q5 at Main, and Q6 at Main using partial aggregates.

### Part F demonstrations

The transfer procedure is created and tested by `-Task transfer`. It moves student 100 from Main to Lahore, checks that the same eight enrollment rows remain visible globally, then moves the student back.

Run the network failure demo separately:

```powershell
.\scripts\failure_demo.ps1
```

The script temporarily disconnects Faisalabad from the Compose network and reconnects it in a `finally` block. Some SQL errors are expected because those queries need an unavailable campus. Local operations should continue to work.

## Direct Docker commands

These commands are useful if you do not want to use the PowerShell helper:

```powershell
docker compose up -d --wait
docker compose exec -T main psql -U postgres -d riphah -v ON_ERROR_STOP=1 -f /project/sql/10_seed_and_distribute.sql
docker compose exec -T main psql -U postgres -d riphah -c "ANALYZE;"
docker compose exec -T lahore psql -U postgres -d riphah -c "ANALYZE;"
docker compose exec -T faisalabad psql -U postgres -d riphah -c "ANALYZE;"
docker compose exec -T main psql -U postgres -d riphah -f /project/sql/20_verify.sql
```

## Reset the whole prototype

This removes all three database volumes and all generated data. Run it only when you want a clean rebuild.

```powershell
.\scripts\run.ps1 -Task reset
.\scripts\run.ps1 -Task all
```

## Design implemented

### A. Horizontal fragmentation

The simple predicates are the campus predicates `Campus = 'M'`, `Campus = 'L'`, `Campus = 'F'`, and the query predicate `CGPA < 2.00` (with its complement `CGPA >= 2.00`). Impossible minterms that combine two different campus values are removed. For this prototype, CGPA is assumed to be present for every student and is enforced as NOT NULL. The brief does not state whether CGPA can be NULL. If NULL values are allowed in the real system, add one `CGPA IS NULL` fragment per campus so reconstruction remains complete. Under the stated prototype assumption, the resulting STUDENT layout has six fragments: campus crossed with the two CGPA ranges. In relational algebra, for each campus X in {M, L, F}, `STUDENT_X_LOW = σ(Campus = X AND CGPA < 2.00)(STUDENT)` and `STUDENT_X_OTHER = σ(Campus = X AND CGPA >= 2.00)(STUDENT)`. All six fragments are allocated to their matching campus.

ENROLL is derived from STUDENT by the student's home campus. For example, `ENROLL_M = ENROLL ⋉ (STUDENT_M_LOW ∪ STUDENT_M_OTHER)` on SID, and similarly for Lahore and Faisalabad. It has three physical fragments, `ENROLL_M`, `ENROLL_L` and `ENROLL_F`. A Lahore student's Faisalabad elective remains in `ENROLL_L`; the course row remains in `COURSE_F`. A Q3 roster for a Faisalabad course can therefore need enrollment rows from all three student-home fragments.

COURSE is horizontally fragmented by the campus offering the course: `COURSE_M`, `COURSE_L`, `COURSE_F`.

### Allocation table

| Fragment or copy | Main | Lahore | Faisalabad |
|---|---|---|---|
| STUDENT_M_LOW, STUDENT_M_OTHER | Primary | Not stored | Not stored |
| STUDENT_L_LOW, STUDENT_L_OTHER | Not stored | Primary | Not stored |
| STUDENT_F_LOW, STUDENT_F_OTHER | Not stored | Not stored | Primary |
| COURSE_M | Primary | Not stored | Not stored |
| COURSE_L | Not stored | Primary | Not stored |
| COURSE_F | Not stored | Not stored | Primary |
| ENROLL_M | Primary | Not stored | Not stored |
| ENROLL_L | Not stored | Primary | Not stored |
| ENROLL_F | Not stored | Not stored | Primary |
| FACULTY_PUBLIC | Replica | Replica | Replica |
| FACULTY_PAYROLL | Primary | Not stored | Not stored |

### B. Vertical fragmentation

`FACULTY_PUBLIC(FID, Name, Dept, Campus, Phone, Email)` is stored at all three campuses. `FACULTY_PAYROLL(FID, Salary, BankAccount)` is stored only at Main. `FID` is the common reconstruction key. Main exposes `faculty_full` as a join view; the view is a convenience layer, not a replacement for physical separation and permissions.

### C. Correctness

`sql/20_verify.sql` checks expected row counts, student ID coverage, unique keys, the three campus distributions, ENROLL home-campus placement, the 5% cross-campus elective rate, COURSE reconstruction and the three faculty public copies. `sql/demo/c_status_trap.sql` shows that a Status split is correct because the three allowed values cover every row without overlap. It is a poor quality choice for this workload: Q1 and the much more frequent Q2 do not filter by Status, so they would have to search every Status fragment. Q6 alone benefits from an Active-only fragment. Correctness means the fragments preserve and reconstruct the data; quality means they serve the workload efficiently.

### D. Allocation and replication

Campus student fragments, course fragments and derived enrollment fragments are stored at their relevant campus. `FACULTY_PUBLIC` is replicated because Q4 occurs 2,000 times per day at all campuses. Main's row trigger propagates inserts, updates and deletes to Lahore and Faisalabad. `FACULTY_PAYROLL` is Main-only because Q5 occurs twice per day and contains sensitive attributes.

The simple read/write break-even estimate assumes Q4 requests are evenly distributed and gives equal cost to one remote read and one remote write. With 2,000 reads/day, about two thirds (1,333) would be remote if the directory lived only at Main. Each update then needs two remote writes, so the message-count break-even is about 667 updates/day. The brief does not specify update frequency, so that figure is an assumption, not an observed value.

### E. Query processing

- Q1 at Lahore is rewritten directly to `STUDENT_L_LOW`, because the workload predicates identify the Lahore low-CGPA minterm. The Lahore demo runs `EXPLAIN ANALYZE` on this local fragment to show that no WAN site is needed.
- Q2 uses the student's home-campus ENROLL fragment. A course join can still contact another campus for cross-campus electives.
- Q3 uses ENROLL fragments from all campuses because ENROLL follows the student, not the course.
- Q4 is served from the local FACULTY_PUBLIC replica.
- Q5 runs at Main and joins the public and payroll vertical fragments.
- Q6 computes counts by program at each fragment first and sends only partial aggregates to Main for the final sum.

The semijoin script compares full COURSE_M transfer bytes with sending distinct course IDs and returning only matching course tuples. It includes cases where a semijoin wins and cases where it loses. The byte model excludes network round-trip latency and protocol overhead.

### F. Discussion extensions

A student transfer changes the student's campus fragment and moves all of that student's ENROLL rows to the new home-campus fragment. This stresses location and fragmentation transparency. `postgres_fdw` lets the procedure address foreign fragments through local names, but the prototype is not a full distributed transaction coordinator. For a production system, transfers would need durable orchestration, retry and reconciliation logic. PostgreSQL 16 documents that `postgres_fdw` manages corresponding remote transactions but does not support preparing those remote transactions for two-phase commit; an error during a multi-server commit can therefore be a distributed consistency risk. See the official [PostgreSQL 16 postgres_fdw documentation](https://www.postgresql.org/docs/16/postgres-fdw.html).

If Faisalabad loses its WAN link for two hours, Q1 can run from its local low-CGPA fragment. Q2 can return local ENROLL_F rows and titles from COURSE_F, but cross-campus course titles are unavailable while the remote course fragments cannot be reached. Q3 can return a local partial roster, but not the complete roster because ENROLL_M and ENROLL_L are remote. Q4 continues from the local FACULTY_PUBLIC replica. Q5 is unavailable there by design. Q6 cannot produce a university-wide result because it needs Main and Lahore fragments. Local caches or carefully managed read replicas could improve read availability, while queued writes would need conflict handling.

If cross-campus electives rise from 5% to 40%, the number of cross-campus enrollment rows rises from 12,000 to about 96,000 out of 240,000, an eightfold increase. Keeping ENROLL by student home campus still favors the frequent Q2 lookup, but it causes far more remote course lookups and makes Q3 more dependent on other campuses. Replicating the small 900-row COURSE catalog at all sites becomes much more attractive. A second option is a hybrid design that keeps enrollment home-campus fragments but adds a course-to-enrollment index or a separate read-optimized roster structure.

## Academic integrity note

The code and design notes were prepared with AI assistance. Before submission, the team must review the implementation, understand and verify the design, make its own final decisions, and cite the AI tools used as required by the assignment.

## Important technical limits

- The dataset is synthetic. It contains no real student, faculty, salary or bank data.
- The three databases are local Docker containers, not three physical campuses connected over a real WAN.
- `postgres_fdw` demonstrates remote access, but this is not a production-grade distributed transaction manager or high-availability setup.
- The directory replication trigger is a teaching example. Production replication needs monitoring, retry handling and reconciliation.
- Query plans and execution times depend on PostgreSQL version, data statistics and the host machine. Capture fresh output from your own run for the final report.
- The compose credentials are intentionally simple and must not be used outside a local demo.

## Project structure

```text
riphah_distributed_db/
  docker-compose.yml
  Makefile
  README.md
  scripts/
    run.ps1
    failure_demo.ps1
  docs/
    attribute-usage-matrix.md
    requirement-map.md
    technical-references.md
  sql/
    init/
      main.sql
      lahore.sql
      faisalabad.sql
    10_seed_and_distribute.sql
    20_verify.sql
    demo/
      a_horizontal.sql
      b_vertical_security.sql
      b_view_comparison.sql
      c_status_trap.sql
      d_allocation_replication.sql
      e_queries_lahore.sql
      e_queries_faisalabad.sql
      e_queries_main.sql
      e_semijoin.sql
      f_transfer_procedure.sql
      f_transfer.sql
      f_failure_faisalabad.sql
      f_failure_main.sql
```
