FROM apache/airflow:3.3.1-python3.12

COPY docker/requirements.txt /requirements.txt

RUN pip install --no-cache-dir -r /requirements.txt

COPY scripts/airflow-init.sh /opt/airflow/scripts/

COPY scripts/bootstrap-roles.sh /opt/airflow/scripts/

COPY scripts/sync-dags.sh /opt/airflow/scripts/

COPY scripts/wait-for-db.sh /opt/airflow/scripts/

COPY scripts/watchdog-entrypoint.sh /opt/airflow/scripts/

RUN chmod +x /opt/airflow/scripts/*.sh