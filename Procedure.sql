/*-----------------------------------------------------------------------------------
Permette al cliente di prendere in prestito una copia di un libro dalla biblioteca,
qualora sia registrato, la sua tessera non sia scaduta e non abbia 3 multe da pagare.
-----------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE EFFETTUA_PRESTITO (NUM_TESS REGISTRAZIONE.NUMERO_TESSERA%TYPE, ISBN_C LIBRO.ISBN%TYPE) IS
    NUMERO_COPIA_PRESTATA  NUMBER(4, 0);    --Numero della copia appartenente al libro prestata al cliente
    COPIE_LIBRO_PRESTATE   NUMBER(4, 0);    --Numero di copie del libro che il cliente ha già attualmente in prestito
    COPIE_TOTALI_PRESTATE  NUMBER(4, 0);    --Numero di copie che il cliente ha già attualmente in prestito
    NUM_MULTE              NUMBER(1, 0);    --Numero di multe non pagate dal cliente
    SCADENZA               DATE;            --Scadenza della tessera del cliente

    TROPPI_PRESTITI        EXCEPTION;       --Si verifica quando il cliente ha preso in prestito più di 10 copie senza averne restituito alcuno
    LIBRO_GIA_PRESTATO     EXCEPTION;       --Si verifica quando il cliente tenta di prendere in prestito la copia di un libro di cui ha già una copia attualmente in prestito
    MULTE_NON_PAGATE       EXCEPTION;       --Si verifica quando il cliente possiede almeno 3 multe da pagare
    TESSERA_SCADUTA        EXCEPTION;       --Si verifica quando il cliente ha la tessera scaduta

BEGIN
    --Restituisce il numero di multe non pagate dal cliente
    SELECT COUNT(*) INTO NUM_MULTE
    FROM MULTA
    WHERE NUMERO_TESSERA = NUM_TESS AND DATA_PAGAMENTO IS NULL;

    --Se il cliente ha 3 multe non pagate, la procedura genera l'eccezione
    IF NUM_MULTE > 2
        THEN RAISE MULTE_NON_PAGATE;
    END IF;

    --Restituisce la data di scadenza della tessera del cliente
    SELECT DATA_SCADENZA_TESSERA INTO SCADENZA
    FROM REGISTRAZIONE
    WHERE NUMERO_TESSERA = NUM_TESS;

    --Se la tessera del cliente è scaduta, la procedura genera l'eccezione
    IF SCADENZA < SYSDATE
        THEN RAISE TESSERA_SCADUTA;
    END IF;

    --Conta il numero di copie prese in prestito dal cliente
    SELECT COUNT (*) INTO COPIE_TOTALI_PRESTATE
    FROM   PRENDE
    WHERE  NUMERO_TESSERA = NUM_TESS;

    --Se il cliente ha già preso in prestito 10 copie nel mese indicato, il trigger genera l'eccezione
    IF COPIE_TOTALI_PRESTATE > 9
        THEN RAISE TROPPI_PRESTITI;
    END IF;

    --Controlla se il cliente ha già attualmente in prestito una copia del libro
    SELECT COUNT(*) INTO COPIE_LIBRO_PRESTATE
    FROM PRENDE
    WHERE NUMERO_TESSERA = NUM_TESS AND ISBN = ISBN_C;

    --Se il cliente ha già una copia del libro attualmente in prestito, la procedura genera l'eccezione
    IF COPIE_LIBRO_PRESTATE > 0
        THEN RAISE LIBRO_GIA_PRESTATO;
    END IF;
    
    --Seleziona la prima copia disponibile (non attualmente prestata) del libro
    SELECT NUMERO_COPIA INTO NUMERO_COPIA_PRESTATA
    FROM COPIA
    WHERE ISBN = ISBN_C AND NUMERO_COPIA NOT IN (SELECT NUMERO_COPIA
                                                FROM PRENDE
                                                WHERE ISBN = ISBN_C)
    FETCH FIRST 1 ROW ONLY;

    --Presta la copia al cliente, stabilendo la data di scadenza del prestito
    INSERT INTO PRENDE (NUMERO_TESSERA, ISBN, NUMERO_COPIA, DATA_INIZIO_PRESTITO, DATA_SCADENZA_PRESTITO)
    VALUES (NUM_TESS, ISBN_C, NUMERO_COPIA_PRESTATA, SYSDATE, ADD_MONTHS(SYSDATE, 12));

    DBMS_OUTPUT.PUT_LINE('Il prestito della copia è avvenuto con successo');

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND      THEN RAISE_APPLICATION_ERROR(-20001, 'Non ci sono copie del libro disponibili da prendere in prestito');
    WHEN TROPPI_PRESTITI    THEN RAISE_APPLICATION_ERROR(-20002, 'Il cliente ha già preso in prestito 10 libri senza restituirne alcuno');
    WHEN LIBRO_GIA_PRESTATO THEN RAISE_APPLICATION_ERROR(-20003, 'Il cliente ha già attualmente in prestito una copia del libro');
    WHEN MULTE_NON_PAGATE   THEN RAISE_APPLICATION_ERROR(-20004, 'Il cliente non può prendere in prestito copie in quanto ha 3 multe da pagare');
    WHEN TESSERA_SCADUTA    THEN RAISE_APPLICATION_ERROR(-20005, 'Il cliente non può prendere in prestito copie in quanto la sua tessera è scaduta');

END;

/*------------------------------------------------------------------------------------------
Permette a un cliente di effettuare la restituzione di una copia presa in prestito.
Se la copia è restituita oltre la scadenza prefissata, viene intestata una multa al cliente.
------------------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE EFFETTUA_RESTITUZIONE (NUM_TESS REGISTRAZIONE.NUMERO_TESSERA%TYPE, ISBN_C LIBRO.ISBN%TYPE, NUM_COPIA NUMBER) IS 
    SCADENZA    DATE;         --Scadenza prefissata al momento del prestito
    IUV_MULTA   CHAR(20);     --IUV della multa da assegnare al cliente

BEGIN
    --Restituisce la data di scadenza prefissata al momento del prestito
    SELECT DATA_SCADENZA_PRESTITO INTO SCADENZA
    FROM PRENDE
    WHERE NUMERO_TESSERA = NUM_TESS AND ISBN = ISBN_C AND NUMERO_COPIA = NUM_COPIA;

    --Se la copia è restituita oltre la data di scadenza, la procedura genera una multa e la attesta al cliente
    IF SCADENZA < SYSDATE
    THEN
        IUV_MULTA := '123-' || TO_CHAR(SYSDATE, 'YYYY-MM') || '-' || LPAD(AUTO_INCREMENT_NUMERO_MULTA.NEXTVAL, 4, 0);
        INSERT INTO MULTA (IUV, NUMERO_TESSERA) VALUES (IUV_MULTA, NUM_TESS);
        DBMS_OUTPUT.PUT_LINE ('Il cliente è stato multato perchè ha restituito la copia in ritardo');
    
    ELSE
        DBMS_OUTPUT.PUT_LINE ('La copia è stata restituita entro la scadenza prefissata');

    END IF;

    --Aggiorna la data di restituzione della copia alla data corrente
    UPDATE PRENDE SET DATA_RESTITUZIONE = SYSDATE WHERE NUMERO_TESSERA = NUM_TESS AND ISBN = ISBN_C AND NUMERO_COPIA = NUM_COPIA;

EXCEPTION
    WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20001, 'La copia che si sta tentando di restituire non è stata presa in prestito dal cliente o non è presente nel database');

END;

/*----------------------------------------------------------------------------------------
Permette a un cliente registrato di partecipare a un evento se ci sono posti disponibili,
se la sua tessera non è scaduta e se non ha 3 multe non pagate.
----------------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE PRENOTA_POSTO_EVENTO (NUM_TESS REGISTRAZIONE.NUMERO_TESSERA%TYPE, DATA_EVENTO DATE) IS
    PARTECIPANTI  NUMBER(3, 0);       --Numero di partecipanti all'evento
    NUM_MULTE     NUMBER(1, 0);       --Numero di multe non pagate dal cliente
    SCADENZA      DATE;               --Data di scadenza della tessera del cliente

    EVENTO_PIENO     EXCEPTION;       --Si verifica quando ci si tenta di prenotarsi a un evento pieno
    MULTE_NON_PAGATE EXCEPTION;       --Si verifica quando il cliente ha 3 multe non pagate
    TESSERA_SCADUTA  EXCEPTION;       --Si verifica quando il cliente ha la tessera scaduta

BEGIN 
    --Restituisce il numero di multe non pagate dal cliente
    SELECT COUNT(*) INTO NUM_MULTE
    FROM MULTA
    WHERE NUMERO_TESSERA = NUM_TESS AND DATA_PAGAMENTO IS NULL;

    --Se il cliente ha 3 multe non pagate, la procedura genera l'eccezione
    IF NUM_MULTE > 2
        THEN RAISE MULTE_NON_PAGATE;
    END IF;

    --Restituisce la data di scadenza della tessera del cliente
    SELECT DATA_SCADENZA_TESSERA INTO SCADENZA
    FROM REGISTRAZIONE
    WHERE NUMERO_TESSERA = NUM_TESS;

    --Se la tessera del cliente è scaduta, la procedura genera l'eccezione
    IF SCADENZA < SYSDATE
        THEN RAISE TESSERA_SCADUTA;
    END IF;

    --Restituisce il numero di partecipanti all'evento
    SELECT COUNT(*) INTO PARTECIPANTI
    FROM SEGUITO
    WHERE TRUNC(DATA_E_ORA_EVENTO) = TRUNC(DATA_EVENTO);

    --Se non ci sono più posti disponibili, la procedura genera l'eccezione
    IF PARTECIPANTI >= 50
        THEN RAISE EVENTO_PIENO;
    END IF;

    --Altrimenti, il cliente viene prenotato per l'evento
    INSERT INTO SEGUITO (DATA_E_ORA_EVENTO, NUMERO_TESSERA)
    VALUES (DATA_EVENTO, NUM_TESS);
    DBMS_OUTPUT.PUT_LINE('Prenotazione effettuata con successo');
    
    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND      THEN RAISE_APPLICATION_ERROR(-20001, 'Il giorno indicato non si terrà nessun evento');
    WHEN EVENTO_PIENO       THEN RAISE_APPLICATION_ERROR(-20002, 'L evento a cui si vuole partecipare non ha più posti disponibili');
    WHEN MULTE_NON_PAGATE   THEN RAISE_APPLICATION_ERROR(-20003, 'Il cliente non può prendere prenotarsi per l evento in quanto ha 3 multe da pagare');
    WHEN TESSERA_SCADUTA    THEN RAISE_APPLICATION_ERROR(-20004, 'Il cliente non può prendere prenotarsi per l evento in quanto la sua tessera è scaduta');

END;

/*--------------------------------------------------------------
Permette ad un cliente di disdire la partecipazione a un evento.
--------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE DISDICI_PRENOTAZIONE_POSTO_EVENTO (NUM_TESS REGISTRAZIONE.NUMERO_TESSERA%TYPE, DATA_EVENTO DATE) IS
    CLIENTE_NON_PRENOTATO    EXCEPTION;      --Si verifica quando il cliente tenta di disdire la prenotazione ad un evento per la quale non è prenotato
    EVENTO_CONCLUSO          EXCEPTION;      --Si verifica quando si cerca di disdire la prenotazione ad un evento concluso

BEGIN
    --Se il cliente tenta di disdire la prenotazione ad un evento già concluso, la procedura genera l'eccezione
    IF DATA_EVENTO < SYSDATE
        THEN RAISE EVENTO_CONCLUSO;
    END IF;

    --Disdice la prenotazione del cliente all'evento
    DELETE FROM SEGUITO WHERE NUMERO_TESSERA = NUM_TESS AND TRUNC(DATA_E_ORA_EVENTO) = TRUNC(DATA_EVENTO);

    --Se il cliente non è prenotato all'evento, la procedura genera l'eccezione
    IF SQL%ROWCOUNT = 0
        THEN RAISE CLIENTE_NON_PRENOTATO;
    END IF;

EXCEPTION
    WHEN EVENTO_CONCLUSO       THEN RAISE_APPLICATION_ERROR (-20001, 'Impossibile disdire la prenotazione per un evento concluso');
    WHEN CLIENTE_NON_PRENOTATO THEN RAISE_APPLICATION_ERROR (-20002, 'Il cliente non è prenotato per l evento indicato');

END;

/*----------------------------------------------------------------------------------------------------------------------
Permette a un bibliotecario di posizionare le copie spedite alla biblioteca da un fornitore mediante un ordine nella 
giusta mensola e nel giusto scaffale.
-----------------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE POSIZIONA_COPIE (DATA_ACQUISTO DATE, ID_F NUMBER) IS
    ISBN_C             LIBRO.ISBN%TYPE;            --ISBN delle copie arrivate
    NUM_COP_ACQ        NUMBER(4, 0);               --Numero totale di copie acquistate con l'ordine
    INIT               CHAR(1);                    --Lettera iniziale del nome del libro al quale appartengono le copie acquistate (per il posizionamento sulla giusta mensola)
    CAT_C              LIBRO.GENERE%TYPE;          --Genere delle copie (per il posizionamento sul giusto scaffale)
    NUM_P              COPIA.NUMERO_PIANO%TYPE;    --Numero di piano dello scaffale su cui vanno posizionate le copie (in base alla lettera iniziale)
    CONT               NUMBER(4, 0);               --Ultimo numero di copia inserito (l'inserimento parte da questo valore)

BEGIN
    --Restituisce l'ISBN e il numero di copie acquistate
    SELECT ISBN_COPIE_ACQUISTATE, NUMERO_COPIE_ACQUISTATE INTO ISBN_C, NUM_COP_ACQ
    FROM ORDINE
    WHERE DATA_ACQUISTO_ORDINE = DATA_ACQUISTO AND ID_FORNITORE = ID_F;

    --Restituisce il genere al quale appartengono le copie
    SELECT DISTINCT SUBSTR(TITOLO, 1, 1), GENERE INTO INIT, CAT_C
    FROM LIBRO
    WHERE ISBN = ISBN_C;

    --Aggiorna il numero del piano dello scaffale sul quale vanno inserite le copie in base alla lettera iniziale del libro a cui appartengono
    IF UPPER(INIT) BETWEEN 'A' AND 'H'
        THEN NUM_P := 1;
    ELSIF UPPER(INIT) BETWEEN 'I' AND 'Q'
        THEN NUM_P := 2;
    ELSE
        NUM_P := 3;
    END IF;

    --Restituisce il massimo numero di copia inserito da cui iniziare l'inserimento
    SELECT MAX(NUMERO_COPIA) INTO CONT
    FROM COPIA
    WHERE ISBN = ISBN_C;

    --Se non ci sono copie di quel determinato libro in biblioteca, il conteggio parte da 0
    IF CONT IS NULL
        THEN CONT := 0;
    END IF;

    --Effettua tanti inserimenti nella tabella copia quante ne sono le copie incluse nell'ordine
    FOR I IN 1..NUM_COP_ACQ LOOP
        CONT := CONT + 1;
        INSERT INTO COPIA (ISBN, NUMERO_COPIA, CONDIZIONE, LETTERA_MENSOLA, NUMERO_PIANO, CATEGORIA_SCAFFALE, DATA_ACQUISTO_ORDINE, ID_FORNITORE)
        VALUES (ISBN_C, CONT, 'NUOVO', INIT, NUM_P, CAT_C, DATA_ACQUISTO, ID_F);
    END LOOP;

    DBMS_OUTPUT.PUT_LINE('Ordini inseriti con successo');

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR (-20001, 'Ordine non trovato');

END;

/*------------------------------------------------------------------------------------------------------
Permette a un bibliotecario di rinnovare una tessera scaduta aggiornando la nuova data di scadenza,
a meno che il cliente non abbia 3 multe da pagare.
------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE RINNOVA_TESSERA (NUM_TESS REGISTRAZIONE.NUMERO_TESSERA%TYPE) IS
    NUM_MULTE      NUMBER(1, 0);  --Numero di multe da pagare del cliente

    TROPPE_MULTE   EXCEPTION;     --Si verifica quando il cliente possiede 3 multe non ancora pagate

BEGIN
    --Restituisce il numero di multe non pagate dal cliente
    SELECT COUNT(*) INTO NUM_MULTE
    FROM MULTA
    WHERE NUMERO_TESSERA = NUM_TESS AND DATA_PAGAMENTO IS NULL;

    --Se il cliente ha tre multe ancora da pagare, la procedura genera l'eccezione    
    IF NUM_MULTE > 2
        THEN RAISE TROPPE_MULTE;
    END IF;

    --Se la tessera è scaduta la procedura rinnova la tessera, impostando come nuova data di scadenza 1 anno a partire dalla data corrente
    THEN UPDATE REGISTRAZIONE SET DATA_SCADENZA_TESSERA = ADD_MONTHS(SYSDATE, 12) WHERE NUMERO_TESSERA = NUM_TESS;
    DBMS_OUTPUT.PUT_LINE('Rinnovo tessera effettuato con successo');

    COMMIT;

EXCEPTION
    WHEN NO_DATA_FOUND THEN RAISE_APPLICATION_ERROR(-20001, 'Tessera non trovata');
    WHEN TROPPE_MULTE  THEN RAISE_APPLICATION_ERROR(-20002, 'Impossibile rinnovare la tessera in quanto il cliente possiede 3 multe da pagare');
        
END;

/*----------------------------------------------------------------------------------------------------
Permette al direttore di visualizzare l'inventario della biblioteca per ordinare copie di libri le cui
disponibilità sono ridotte.
----------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE PROCEDURE CONTROLLA_INVENTARIO (ID_F NUMBER, NUM_COPIE NUMBER) IS
BEGIN
    --Restituisce i libri presenti in biblioteca e il relativo numero di copie disponibili
    FOR BOOK IN (SELECT L.ISBN, COUNT(NUMERO_COPIA) AS COPIE_DISPONIBILI
                 FROM LIBRO L JOIN COPIA C ON L.ISBN = C.ISBN
                 GROUP BY (L.ISBN))
    LOOP
        --Se il numero di copie disponibili di un libro è insufficiente, si effettua un ordine di copie di quel libro da un fornitore casuale
        IF BOOK.COPIE_DISPONIBILI < 5
            THEN INSERT INTO ORDINE (DATA_ACQUISTO_ORDINE, ISBN_COPIE_ACQUISTATE, NUMERO_COPIE_ACQUISTATE, ID_FORNITORE)
            VALUES (SYSDATE, BOOK.ISBN, NUM_COPIE, ID_F);
        END IF;
    END LOOP;

    COMMIT;

END;