/*-----------------------------------------------------------------------------------------------------------
SCHEDULER 1:
Elimina dal database eventi, informazioni su chi li ha seguiti, turni, prestiti e multe precedenti di un mese.
Viene eseguito il primo giorno di ogni mese.
------------------------------------------------------------------------------------------------------------*/
BEGIN
    DBMS_SCHEDULER.CREATE_JOB
    (
        job_name        => 'Pulizia_Database',
        job_type        => 'PLSQL_BLOCK',
        job_action      => 'BEGIN
                                DELETE FROM SEGUITO
                                WHERE DATA_E_ORA_EVENTO < SYSDATE - 30;

                                DELETE FROM EVENTO
                                WHERE DATA_E_ORA_EVENTO < SYSDATE - 30;

                                DELETE FROM TURNO
                                WHERE DATA_E_ORA_TURNO < SYSDATE - 30;

                                DELETE FROM PRENDE
                                WHERE DATA_SCADENZA_PRESTITO < SYSDATE - 30;

                                DELETE FROM MULTA
                                WHERE DATA_PAGAMENTO < SYSDATE - 30;
                            END;',
        start_date      => TO_DATE('01-SEP-2023', 'DD-MM-YYYY'),
        repeat_interval => 'FREQ = MONTHLY',
        end_date        => NULL,
        auto_drop       => FALSE,
        enabled         => TRUE,
        comments        => 'Effettua la pulizia del database eliminando dati obsoleti.'
    );
END;

--Eliminazione dello scheduler
BEGIN
    DBMS_SCHEDULER.DROP_JOB('Pulizia_Database');
END;