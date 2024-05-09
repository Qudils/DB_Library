/*---------------------------------------------------------------------------------------------------------------
Permette a un cliente di verificare la disponibilità attuale di copie prestabili di un libro.
----------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE FUNCTION VISUALIZZA_DISPONIBILITA_COPIE (ISBN_C LIBRO.ISBN%TYPE)
RETURN NUMBER
IS
    COPIE_DISPONIBILI NUMBER(4, 0);     --Numero di copie del libro non attulamente in prestito a qualche cliente

BEGIN
    --Conta il numero di copie del libro disponibili
    SELECT COUNT(NUMERO_COPIA) INTO COPIE_DISPONIBILI
    FROM COPIA
    WHERE ISBN = ISBN_C AND NUMERO_COPIA NOT IN (SELECT NUMERO_COPIA
                                                 FROM PRENDE
                                                 WHERE ISBN = ISBN_C);

    --E lo restituisce
    RETURN COPIE_DISPONIBILI;

EXCEPTION
    WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE ('Il libro non è presente in biblioteca, si prega di sceglierne un altro');

END;

/*-------------------------------------------------------------------------------------------------
Permette a un cliente di verificare la disponibilità di posti per un evento che ancora deve tenersi.
-------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE FUNCTION VISUALIZZA_POSTI_DISPONIBILI_EVENTO (DATA_EVENTO DATE)
RETURN NUMBER
IS
    POSTI_OCCUPATI NUMBER(2, 0);     --Numero di posti occupati per l'evento

BEGIN
    --Conta il numero di posti disponibili per l'evento
    SELECT COUNT(*) INTO POSTI_OCCUPATI
    FROM SEGUITO
    WHERE TRUNC(DATA_E_ORA_EVENTO) = TRUNC(DATA_EVENTO) AND TRUNC(DATA_E_ORA_EVENTO) > SYSDATE;

    --Restituisce il numero di posti disponibili per l'evento
    RETURN (50 - POSTI_OCCUPATI);

EXCEPTION
    WHEN NO_DATA_FOUND    THEN DBMS_OUTPUT.PUT_LINE ('Evento non trovato');

END;

/*-------------------------------------------------------------------------------------------------
Permette a un cliente di visualizzare la valutazione media di un libro.
-------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE FUNCTION VISUALIZZA_VALUTAZIONE_MEDIA_LIBRO (ISBN_C LIBRO.ISBN%TYPE)
RETURN NUMBER
IS
    VALUTAZIONE_MEDIA NUMBER(2, 0);     --Valutazione media delle recensioni del libro

BEGIN
    --Calcola la valutazione media delle recensioni libro
    SELECT AVG(VALUTAZIONE) INTO VALUTAZIONE_MEDIA
    FROM RECENSIONE
    WHERE ISBN = ISBN_C;

    --Restituisce la valutazione media delle recensioni del libro
    RETURN VALUTAZIONE_MEDIA;

EXCEPTION
    WHEN NO_DATA_FOUND    THEN DBMS_OUTPUT.PUT_LINE ('Libro non trovato');

END;

/*----------------------------------------------------------------------------------------------------------------------
Permette ad un bibliotecario e al direttore di visualizzare il numero totali di copie di un libro presenti in biblioteca.
-----------------------------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE FUNCTION VISUALIZZA_NUMERO_COPIE (ISBN_C LIBRO.ISBN%TYPE)
RETURN NUMBER
IS
    COPIE_TOTALI NUMBER(3, 0);  --Numero totali di copie del libro presenti in biblioteca

BEGIN
    --Conta il numero di copie del libro presenti in biblioteca
    SELECT COUNT(NUMERO_COPIA) INTO COPIE_TOTALI
    FROM COPIA
    WHERE ISBN = ISBN_C;

    --E lo restituisce
    RETURN COPIE_TOTALI;

EXCEPTION
    WHEN NO_DATA_FOUND THEN DBMS_OUTPUT.PUT_LINE ('Il libro non è presente in biblioteca, si prega di sceglierne un altro');

END;

/*-------------------------------------------------------------------------------------------
Permette a un direttore di visualizzare il numero totale di copie del libro ordinate.
-------------------------------------------------------------------------------------------*/
CREATE OR REPLACE FUNCTION VISUALIZZA_ORDINE (ISBN_C LIBRO.ISBN%TYPE)
RETURN NUMBER
IS
    NUM_COP_ACQ NUMBER(3, 0);       --Numero totale di copie del libro ordinate

BEGIN
    --Calcola il numero totale di copie del libro ordinate
    SELECT SUM(NUMERO_COPIE_ACQUISTATE) INTO NUM_COP_ACQ
    FROM ORDINE
    WHERE ISBN_COPIE_ACQUISTATE = ISBN_C;

    --E lo restituisce
    RETURN NUM_COP_ACQ;

EXCEPTION
    WHEN NO_DATA_FOUND    THEN DBMS_OUTPUT.PUT_LINE ('Ordine non trovato');

END;