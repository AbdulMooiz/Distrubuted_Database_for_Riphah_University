COMPOSE = docker compose
PSQL = psql -U postgres -d riphah
M = $(COMPOSE) exec -T main $(PSQL)
L = $(COMPOSE) exec -T lahore $(PSQL)
F = $(COMPOSE) exec -T faisalabad $(PSQL)

.PHONY: up seed verify all demo_a demo_b demo_c demo_d demo_e semijoin transfer down reset

all: up seed verify demo_a demo_b demo_c demo_d demo_e semijoin transfer

up:
	$(COMPOSE) up -d --wait

seed:
	$(M) -v ON_ERROR_STOP=1 -f /project/sql/10_seed_and_distribute.sql
	$(M) -c "ANALYZE;"
	$(L) -c "ANALYZE;"
	$(F) -c "ANALYZE;"

verify:
	$(M) -v ON_ERROR_STOP=1 -f /project/sql/20_verify.sql

demo_a:
	$(F) -v ON_ERROR_STOP=1 -f /project/sql/demo/a_horizontal.sql

demo_b:
	$(L) -v ON_ERROR_STOP=1 -f /project/sql/demo/b_vertical_security.sql
	$(M) -v ON_ERROR_STOP=1 -f /project/sql/demo/b_view_comparison.sql

demo_c:
	$(M) -v ON_ERROR_STOP=1 -f /project/sql/demo/c_status_trap.sql

demo_d:
	$(M) -v ON_ERROR_STOP=1 -f /project/sql/demo/d_allocation_replication.sql

demo_e:
	$(L) -v ON_ERROR_STOP=1 -f /project/sql/demo/e_queries_lahore.sql
	$(F) -v ON_ERROR_STOP=1 -f /project/sql/demo/e_queries_faisalabad.sql
	$(M) -v ON_ERROR_STOP=1 -f /project/sql/demo/e_queries_main.sql

semijoin:
	$(F) -v ON_ERROR_STOP=1 -f /project/sql/demo/e_semijoin.sql

transfer:
	$(M) -v ON_ERROR_STOP=1 -f /project/sql/demo/f_transfer_procedure.sql
	$(M) -v ON_ERROR_STOP=1 -f /project/sql/demo/f_transfer.sql

down:
	$(COMPOSE) down

reset:
	$(COMPOSE) down -v
