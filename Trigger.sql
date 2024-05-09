/*---------------------------------------------------------------------------------------------------------
Lo stesso giorno possono esserci massimo 3 bibliotecari a svolgere il proprio turno.
Un bibliotecario può svolgere al massimo 2 turni a settimana.
Un bibliotecario che svolge un turno di 8 ore non può lavorare il giorno seguente.
----------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_TURNO
BEFORE INSERT OR UPDATE ON TURNO
FOR EACH ROW

DECLARE
    NUM_BIBLIO              NUMBER(1, 0);  --Numero di bibliotecari che svolgono il proprio turno nella data indicata
    NUM_TURNI               NUMBER(1, 0);  --Numero di turni svolti dal bibliotecario in questa settimana
    DUR_TUR_PREC            NUMBER(1, 0);  --Durata del turno del bibliotecario nel giorno precedente

    TROPPI_BIBLIOTECARI     EXCEPTION;     --Si verifica quando nella data indicata ci sono già 3 bibliotecari che svolgono il proprio turno
    TROPPI_TURNI            EXCEPTION;     --Si verifica quando il bibliotecario svolge più di 2 turni a settimana
    TURNO_VECCHIO           EXCEPTION;     --Si verifica quando si cerca di inserire un turno in una data precedente a quella corrente
    BIBLIOTECARIO_STANCO    EXCEPTION;     --Si verifica quando si assegna un turno ad un bibliotecario in un giorno successivo o precedente a un turno in cui deve lavorare 8 ore

BEGIN
    --Se si tenta di inserire un turno in una data precedente a quella corrente, il trigger genera l'eccezione
    IF :NEW.DATA_E_ORA_TURNO < SYSDATE
        THEN RAISE TURNO_VECCHIO;
    END IF;

    --Conta il numero di turni e il numero di ore svolti dal bibliotecario in questa settimana
    SELECT COUNT(*) INTO NUM_TURNI
    FROM TURNO
    WHERE NUMERO_MATRICOLA = :NEW.NUMERO_MATRICOLA AND TO_CHAR(DATA_E_ORA_TURNO, 'IW') = TO_CHAR(:NEW.DATA_E_ORA_TURNO, 'IW');

    --Se il bibliotecario svolge già 2 turni in questa settimana, il trigger genera l'eccezione
    IF NUM_TURNI > 1
        THEN RAISE TROPPI_TURNI;
    END IF;
    
    --Conta il numero di bibliotecari che svolgono il proprio turno nella data in cui si vuole inserire il turno
    SELECT COUNT(*) INTO NUM_BIBLIO
    FROM TURNO
    WHERE TRUNC(DATA_E_ORA_TURNO) = TRUNC(:NEW.DATA_E_ORA_TURNO);

    --Se ci sono già 3 bibliotecari, il trigger genera l'eccezione
    IF NUM_BIBLIO > 2
        THEN RAISE TROPPI_BIBLIOTECARI;
    END IF;

    --Restituisce la durata del turno assegnato al bibliotecario nel giorno precedente (se gli è stato assegnato)
    SELECT DURATA_TURNO INTO DUR_TUR_PREC
    FROM TURNO
    WHERE NUMERO_MATRICOLA = :NEW.NUMERO_MATRICOLA AND DATA_E_ORA_TURNO = :NEW.DATA_E_ORA_TURNO - 1;

    --Se il giorno precedente il bibliotecario ha svolto un turno di 8 ore, il trigger genera l'eccezione
    IF DUR_TUR_PREC = 8
        THEN RAISE BIBLIOTECARIO_STANCO;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND          THEN NULL;
    WHEN TURNO_VECCHIO          THEN RAISE_APPLICATION_ERROR(-20001, 'Impossibile inserire un turno in una data precedente a quella corrente');
    WHEN TROPPI_BIBLIOTECARI    THEN RAISE_APPLICATION_ERROR(-20002, 'Nella data indicata ci sono già 3 bibliotecari che svolgeranno il proprio turno');
    WHEN TROPPI_TURNI           THEN RAISE_APPLICATION_ERROR(-20003, 'Il bibliotecario svolge già 2 turni nella settimana indicata');
    WHEN BIBLIOTECARIO_STANCO   THEN RAISE_APPLICATION_ERROR(-20004, 'Il bibliotecario ha svolto un turno di 8 ore e deve riposare');

END;

/*------------------------------------------------------------------------------------------------
All'interno della biblioteca possono essere registrati al massimo 15 bibliotecari.
Per poter essere assunti come bibliotecario bisogna avere un'età compresa tra i 18 e i 65 anni.
------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_BIBLIOTECARIO
BEFORE INSERT OR UPDATE ON BIBLIOTECARIO
FOR EACH ROW

DECLARE
    NUM_BIBLIO              NUMBER(2, 0);     --Numero di bibliotecari registrati nella biblioteca

    TROPPI_BIBLIOTECARI     EXCEPTION;        --Si verifica quando si supera il limite massimo di bibliotecari
    BIBLIOTECARIO_MINORENNE EXCEPTION;        --Si verifica quando il bibliotecario che si vuole inserire è minorenne
    BIBLIOTECARIO_ANZIANO   EXCEPTION;        --Si verifica quando il bibliotecario che si vuole inserire è troppo anziano

BEGIN
    --Conta il numero di bibliotecari registrati alla biblioteca
    SELECT COUNT (*) INTO NUM_BIBLIO
    FROM BIBLIOTECARIO;

    --Se il numero di bibliotecari registrati alla biblioteca supera il limite massimo, il trigger genera l'eccezione
    IF NUM_BIBLIO > 14
        THEN RAISE TROPPI_BIBLIOTECARI;
    END IF;

    --Se il bibliotecario che si sta tentando di inserire è minorenne, il trigger genera l'eccezione
    IF TRUNC (MONTHS_BETWEEN(SYSDATE, :NEW.DATA_NASCITA_BIBLIOTECARIO) / 12) < 18
            THEN RAISE BIBLIOTECARIO_MINORENNE;
    END IF;

    --Se il bibliotecario che si sta tentando di inserire è troppo anziano, il trigger genera l'eccezione
    IF TRUNC (MONTHS_BETWEEN(SYSDATE, :NEW.DATA_NASCITA_BIBLIOTECARIO) / 12) > 65
            THEN RAISE BIBLIOTECARIO_ANZIANO;
    END IF;

EXCEPTION
    WHEN TROPPI_BIBLIOTECARI     THEN RAISE_APPLICATION_ERROR(-20001, 'Numero massimo di bibliotecari raggiunto');
    WHEN BIBLIOTECARIO_MINORENNE THEN RAISE_APPLICATION_ERROR(-20002, 'Il bibliotecario che si sta tentando di inserire è minorenne');
    WHEN BIBLIOTECARIO_ANZIANO   THEN RAISE_APPLICATION_ERROR(-20003, 'Il bibliotecario che si sta tentando di inserire è troppo anziano');

END;

/*------------------------------------------------------------------------------------------------
Un bibliotecario non può assistere un cliente in una data in cui non svolge il suo turno.
------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_ASSISTENZA
BEFORE INSERT OR UPDATE ON ASSISTE
FOR EACH ROW

DECLARE
    CHECK_TURNO               NUMBER(1, 0);     --Vale 0 se il bibliotecario ha svolto il proprio turno nella data indicata e 1 altrimenti

    DATA_ASSISTENZA_SBAGLIATA EXCEPTION;        --Si verifica quando si tenta di inserire una data di assistenza in cui il bibliotecario non ha svolto il proprio turno
    DATA_INCOERENTE           EXCEPTION;        --Si verifica quando la data di assistenza è successiva a quella corrente

BEGIN
    --Se la data di assistenza è successiva a quella corrente, il trigger genera l'eccezione
    IF :NEW.DATA_ASSISTENZA > SYSDATE
        THEN RAISE DATA_INCOERENTE;
    END IF;

    --Controlla se il bibliotecario ha svolto il proprio turno nella data indicata
    SELECT COUNT (*) INTO CHECK_TURNO
    FROM TURNO T JOIN BIBLIOTECARIO B ON T.NUMERO_MATRICOLA = B.NUMERO_MATRICOLA
    WHERE T.NUMERO_MATRICOLA = :NEW.NUMERO_MATRICOLA AND TRUNC(DATA_E_ORA_TURNO) = :NEW.DATA_ASSISTENZA;

    --Se il bibliotecario non ha svolto il proprio turno nella data dell'assistenza, il trigger genera l'eccezione
    IF CHECK_TURNO = 0
        THEN RAISE DATA_ASSISTENZA_SBAGLIATA;
    END IF;

EXCEPTION
    WHEN DATA_ASSISTENZA_SBAGLIATA THEN RAISE_APPLICATION_ERROR(-20001, 'Il bibliotecario non ha svolto il proprio turno nella data indicata');
    WHEN DATA_INCOERENTE           THEN RAISE_APPLICATION_ERROR(-20002, 'La data di assistenza è incoerente');

END;

/*------------------------------------------------------------------------------------------------
Per potersi accedere alla biblioteca bisogna avere un'età compresa tra i 14 e i 70 anni.
------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_CLIENTE
BEFORE INSERT OR UPDATE ON CLIENTE
FOR EACH ROW

DECLARE
    CLIENTE_PICCOLO EXCEPTION;        --Si verifica quando si tenta di inserire un cliente con età minore ai 14 anni
    CLIENTE_ANZIANO EXCEPTION;        --Si verifica quando si tenta di inserire un cliente troppo anziano

BEGIN
    --Il trigger genera un'eccezione se il cliente che si vuole inserire è minorenne
    IF TRUNC (MONTHS_BETWEEN(SYSDATE, :NEW.DATA_NASCITA_CLIENTE) / 12) < 14
        THEN RAISE CLIENTE_PICCOLO;
    END IF;

    --O troppo anziano
    IF TRUNC (MONTHS_BETWEEN(SYSDATE, :NEW.DATA_NASCITA_CLIENTE) / 12) > 70
            THEN RAISE CLIENTE_ANZIANO;
    END IF;

EXCEPTION
    WHEN CLIENTE_PICCOLO THEN RAISE_APPLICATION_ERROR(-20001, 'Il cliente che si sta tentando di registrare ha meno di 14 anni');
    WHEN CLIENTE_ANZIANO THEN RAISE_APPLICATION_ERROR(-20002, 'Il cliente che si sta tentando di registrare è troppo anziano');

END;

/*------------------------------------------------------------------------------------------------
Nella biblioteca può tenersi un solo evento dello stesso tipo al mese.
------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_EVENTO
BEFORE INSERT OR UPDATE ON EVENTO
FOR EACH ROW

DECLARE
    CHECK_EVENTO                NUMBER(1, 0);   --Vale 1 se nel mese indicato si terrà o si è già tenuto un evento dello stesso tipo e 0 altrimenti

    TROPPI_EVENTI_MESE          EXCEPTION;      --Si verifica quando si tiene più di un evento dello stesso tipo lo stesso mese
    EVENTO_VECCHIO              EXCEPTION;      --Si verifica quando si tenta di inserire un evento in una data precedente a quella corrente

BEGIN
    --Se si tenta di inserire un evento in una data precedente a quella corrente, il trigger genera l'eccezione
    IF :NEW.DATA_E_ORA_EVENTO < SYSDATE
        THEN RAISE EVENTO_VECCHIO;
    END IF;

    --Controlla se nel mese indicato non si terrà o si è già tenuto un evento dello stesso tipo
    SELECT COUNT(*) INTO CHECK_EVENTO
    FROM EVENTO
    WHERE LOWER(NOME_EVENTO) = LOWER(:NEW.NOME_EVENTO) AND TO_CHAR(DATA_E_ORA_EVENTO, 'MM-YYYY') = TO_CHAR(:NEW.DATA_E_ORA_EVENTO, 'MM-YYYY');

    --Se si terrà già un evento dello stesso tipo nel mese indicato, il trigger genera l'eccezione 
    IF CHECK_EVENTO > 0
        THEN RAISE TROPPI_EVENTI_MESE;
    END IF;

EXCEPTION
    WHEN TROPPI_EVENTI_MESE   THEN RAISE_APPLICATION_ERROR(-20001, 'Nel mese indicato si terrà già un evento dello stesso tipo');
    WHEN EVENTO_VECCHIO       THEN RAISE_APPLICATION_ERROR(-20002, 'La data del nuovo evento non può essere precedente a quella corrente');

END;

/*------------------------------------------------------------------------------------------------
La data di recensione di un libro deve essere successiva al suo anno di pubblicazione.
La data di recensione di un libro, da parte di un cliente, non può essere precedente alla sua data
di registrazione alla biblioteca.
------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_RECENSIONE
BEFORE INSERT ON RECENSIONE
FOR EACH ROW

DECLARE
    ANNO_LIBRO             NUMBER(4, 0);       --Anno di pubblicazione del libro che si vuole recensire
    DATA_REG               DATE;               --Data di registrazione del cliente alla biblioteca
    SCADENZA               DATE;               --Data di scadenza della tessera del cliente

    DATA_INCOERENTE        EXCEPTION;          --Si verifica quando la data di recensione del libro è minore del suo anno di pubblicazione
    CLIENTE_NON_REGISTRATO EXCEPTION;          --Si verifica quando il cliente tenta di recensire un libro prima di essersi registrato alla biblioteca

BEGIN
    --Restituisce la data di registrazione del cliente alla biblioteca
    SELECT DATA_REGISTRAZIONE, DATA_SCADENZA_TESSERA INTO DATA_REG, SCADENZA
    FROM REGISTRAZIONE
    WHERE NUMERO_TESSERA = :NEW.NUMERO_TESSERA;

    --Se l'utente tenta di recensire un libro senza essere registrato, il trigger genera l'eccezione
    IF DATA_REG > :NEW.DATA_RECENSIONE OR :NEW.DATA_RECENSIONE > SCADENZA
        THEN RAISE CLIENTE_NON_REGISTRATO;
    END IF;

    --Restituisce l'anno di pubblicazione del libro che si vuole recensire
    SELECT ANNO_PUBBLICAZIONE INTO ANNO_LIBRO
    FROM   LIBRO
    WHERE  ISBN = :NEW.ISBN;

    --Se la data della recensione è minore dell'anno di pubblicazione del libro o maggiore della data attuale, il trigger genera l'eccezione
    IF EXTRACT(YEAR FROM :NEW.DATA_RECENSIONE) < ANNO_LIBRO OR :NEW.DATA_RECENSIONE > SYSDATE
        THEN RAISE DATA_INCOERENTE;
    END IF;

EXCEPTION
    WHEN NO_DATA_FOUND          THEN RAISE_APPLICATION_ERROR(-20001, 'Cliente non registrato o libro non presente in biblioteca');
    WHEN DATA_INCOERENTE        THEN RAISE_APPLICATION_ERROR(-20002, 'La data della recensione è incoerente');
    WHEN CLIENTE_NON_REGISTRATO THEN RAISE_APPLICATION_ERROR(-20003, 'Il cliente non è registrato alla biblioteca o la sua tessera è scaduta');

END;

/*----------------------------------------------------------------------------
L'anno di pubblicazione di un libro non può essere successivo all'anno corrente.
----------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_LIBRO
BEFORE INSERT OR UPDATE ON LIBRO
FOR EACH ROW

DECLARE
    ANNO_PUBBLICAZIONE_INCOERENTE EXCEPTION;   --Si verifica quando si tenta di inserire un libro non ancora pubblicato

BEGIN
    --Se si tenta di inserire un libro non ancora pubblicato, il trigger genera l'eccezione
    IF :NEW.ANNO_PUBBLICAZIONE > EXTRACT(YEAR FROM SYSDATE)
        THEN RAISE ANNO_PUBBLICAZIONE_INCOERENTE;
    END IF;

EXCEPTION
    WHEN ANNO_PUBBLICAZIONE_INCOERENTE THEN RAISE_APPLICATION_ERROR(-20001, 'Il libro non è stato ancora pubblicato');

END;

/*-----------------------------------------------------------------------------------------------------------------------
Una copia non può essere ordinata prima della pubblicazione del libro al quale appartiene.
Non è possibile effettuare ordini di copie dai fornitori se la capienza della mensola sulla quale andrebbero posizionate
è stata superata.
-----------------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_ORDINE
BEFORE INSERT OR UPDATE ON ORDINE
FOR EACH ROW

DECLARE
    PUBBLICAZIONE           NUMBER (4, 0);    --Anno di pubblicazione del libro spedito con l'ordine
    COPIE_POSSEDUTE         NUMBER (4, 0);    --Numero di copie dello stesso tipo già possedute in biblioteca
    INIZIALE_LIBRO          CHAR   (1);       --Lettera iniziale del libro acquistato
    GENERE_LIBRO            VARCHAR(20);      --Genere del libro acquistato
    NUM_PIA                 NUMBER (1, 0);    --Numero del piano dello scaffale sul quale le copie vanno posizionate
    CAPIENZA_MENSOLA        NUMBER (4, 0);    --Capienza massima della mensola

    TROPPE_COPIE            EXCEPTION;        --Si verifica quando si tenta di ordinare delle copie che non si riescono a posizionare nella mensola perchè già piena
    DATA_INCOERENTE         EXCEPTION;        --Si verifica quando la data di acquisto dell'ordine è successiva a quella corrente o all'anno di pubblicazione del libro

BEGIN
    --Restituisce l'anno di pubblicazione del libro ordinato
    SELECT ANNO_PUBBLICAZIONE INTO PUBBLICAZIONE
    FROM LIBRO
    WHERE ISBN = :NEW.ISBN_COPIE_ACQUISTATE;

    --Se la data di acquisto dell'ordine è successiva a quella corrente o precedente all'anno di pubblicazione del libro, il trigger genera l'eccezione
    IF :NEW.DATA_ACQUISTO_ORDINE > SYSDATE OR EXTRACT(YEAR FROM :NEW.DATA_ACQUISTO_ORDINE) < PUBBLICAZIONE
        THEN RAISE DATA_INCOERENTE;
    END IF;

    --Restituisce la lettera iniziale del libro e il genere al quale appartiene
    SELECT DISTINCT SUBSTR(TITOLO, 1, 1), GENERE INTO INIZIALE_LIBRO, GENERE_LIBRO
    FROM LIBRO
    WHERE ISBN = :NEW.ISBN_COPIE_ACQUISTATE;

    --Restituisce il numero del piano dello scaffale sul quale vanno posizionate le copie
    SELECT S.NUMERO_PIANO INTO NUM_PIA
    FROM MENSOLA M JOIN SCAFFALE S ON M.NUMERO_PIANO = S.NUMERO_PIANO AND M.CATEGORIA_SCAFFALE = S.CATEGORIA_SCAFFALE
    WHERE S.CATEGORIA_SCAFFALE = GENERE_LIBRO AND M.LETTERA_MENSOLA = INIZIALE_LIBRO;
    
    --Restituisce il numero di copie posizionate sulla mensola sulla quale andrebbero posizionate le copie acquistate e la relativa capienza massima
    SELECT COUNT(*), CAPIENZA INTO COPIE_POSSEDUTE, CAPIENZA_MENSOLA
    FROM COPIA C JOIN MENSOLA M ON C.LETTERA_MENSOLA = M.LETTERA_MENSOLA AND C.CATEGORIA_SCAFFALE = M.CATEGORIA_SCAFFALE
    WHERE M.LETTERA_MENSOLA = INIZIALE_LIBRO AND M.CATEGORIA_SCAFFALE = GENERE_LIBRO AND M.NUMERO_PIANO = NUM_PIA
    GROUP BY (CAPIENZA);

    --Se non c'è più spazio sulla mensola, il trigger genera l'eccezione
    IF COPIE_POSSEDUTE + :NEW.NUMERO_COPIE_ACQUISTATE > CAPIENZA_MENSOLA
        THEN RAISE TROPPE_COPIE;
    END IF;
    
EXCEPTION
    WHEN NO_DATA_FOUND        THEN RAISE_APPLICATION_ERROR(-20001, 'Le copie che si sta tentando di ordinare appartengono a un libro non presente in biblioteca');
    WHEN TROPPE_COPIE         THEN RAISE_APPLICATION_ERROR(-20002, 'Non è possibile acquistare nuove copie di questo libro in quanto la mensola è piena');
    WHEN DATA_INCOERENTE      THEN RAISE_APPLICATION_ERROR(-20003, 'La data di acquisto dell ordine è incoerente');

END;

/*----------------------------------------------------------------------------------------
Il numero del piano dello scaffale al quale appartiene una mensola dipende dalla
lettera della mensola.
-----------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_MENSOLA
BEFORE INSERT OR UPDATE ON MENSOLA
FOR EACH ROW

DECLARE
    NUMERO_PIANO_SBAGLIATO EXCEPTION;       --Si verifica quando il numero del piano dello scaffale al quale appartiene la mensola non corrisponde alla lettera della mensola

BEGIN
    --Se il numero del piano dello scaffale al quale appartiene la mensola non corrisponde alla lettera della mensola, il trigger genera l'eccezione
    IF (LOWER(:NEW.LETTERA_MENSOLA) BETWEEN 'a' and 'h' AND :NEW.NUMERO_PIANO <> 1) OR (LOWER(:NEW.LETTERA_MENSOLA) BETWEEN 'i' and 'q' AND :NEW.NUMERO_PIANO <> 2)
    OR (LOWER(:NEW.LETTERA_MENSOLA) BETWEEN 'r' and 'z' AND :NEW.NUMERO_PIANO <> 3)
        THEN RAISE NUMERO_PIANO_SBAGLIATO;
    END IF;

EXCEPTION
    WHEN NUMERO_PIANO_SBAGLIATO THEN RAISE_APPLICATION_ERROR(-20001, 'Il piano dello scaffale non corrisponde a quello a cui la mensola dovrebbe appartenere');

END;

/*----------------------------------------------------------------------------------------
La data di acquisto di uno scaffale non può essere precedente alla data corrente di 5 anni.
----------------------------------------------------------------------------------------*/
CREATE OR REPLACE TRIGGER CONTROLLO_SCAFFALE
BEFORE INSERT OR UPDATE ON SCAFFALE
FOR EACH ROW

DECLARE
    SCAFFALE_VECCHIO EXCEPTION;     --Si verifica quando si tenta di inserire uno scaffale acquistato più di 5 anni fa
    DATA_INCOERENTE  EXCEPTION;     --Si verifica quando si tenta di inserire uno scaffale la cui data di acquisto è successiva a quella corrente

BEGIN
    --Se lo scaffale è troppo vecchio, il trigger genera l'eccezione
    IF ADD_MONTHS(:NEW.DATA_ACQUISTO_SCAFFALE, 60) < SYSDATE
        THEN RAISE SCAFFALE_VECCHIO;
    END IF;

    --Se la data di acquisto è successiva alla data corrente, il trigger genera l'eccezione
    IF :NEW.DATA_ACQUISTO_ORDINE > SYSDATE
        THEN RAISE DATA_INCOERENTE;
    END IF;

EXCEPTION
    WHEN SCAFFALE_VECCHIO THEN RAISE_APPLICATION_ERROR(-20001, 'Lo scaffale è troppo vecchio per essere montato nella biblioteca');
    WHEN DATA_INCOERENTE  THEN RAISE_APPLICATION_ERROR(-20002, 'La data di acquisto dello scaffale è incoerente');

END;