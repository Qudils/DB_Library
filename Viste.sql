/*------------------------------------------------------------------------------------
Permette al cliente di visualizzare gli eventi che si terranno nella biblioteca e
i posti disponibili.
Utilizza la function VISUALIZZA_POSTI_DISPONIBILI_EVENTO.
------------------------------------------------------------------------------------*/
CREATE OR REPLACE VIEW EVENTI_DISPONIBILI AS
SELECT DISTINCT DATA_E_ORA_EVENTO, VISUALIZZA_POSTI_DISPONIBILI_EVENTO (DATA_E_ORA_EVENTO) AS POSTI_DISPONIBILI
FROM EVENTO
WHERE TRUNC(DATA_E_ORA_EVENTO) > SYSDATE;

--Utilizzo della vista
SELECT * FROM EVENTI_DISPONIBILI;

/*-------------------------------------------------------------------------------------------
Permette al cliente di visualizzare i libri disponibili in biblioteca, il numero di 
copie disponibili per poter essere prese in prestito e la valutazione media delle recensioni.
Utilizza le function VISUALIZZA_NUMERO_COPIE e VISUALIZZA_VALUTAZIONE_MEDIA_LIBRO.
-------------------------------------------------------------------------------------------*/
CREATE OR REPLACE VIEW LIBRI_CATALOGATI AS
SELECT DISTINCT ISBN, TITOLO, GENERE, VISUALIZZA_DISPONIBILITA_COPIE (ISBN) AS COPIE_DISPONIBILI, VISUALIZZA_VALUTAZIONE_MEDIA_LIBRO (ISBN) AS VALUTAZIONE_MEDIA
FROM LIBRO;

--Utilizzo della vista
SELECT * FROM LIBRI_CATALOGATI;

/*-------------------------------------------------------------------------------------------
Permette al cliente di visualizzare i libri che ha preso in prestito e la data di scadenza
entro la quale deve restituirli.
-------------------------------------------------------------------------------------------*/
CREATE OR REPLACE VIEW PRESTITI_EFFETTUATI AS
SELECT DISTINCT TITOLO AS LIBRO_PRESO_IN_PRESTITO, DATA_INIZIO_PRESTITO AS INIZIO_PRESTITO, DATA_SCADENZA_PRESTITO AS SCADENZA, R.NUMERO_TESSERA
FROM REGISTRAZIONE R JOIN PRENDE P ON R.NUMERO_TESSERA = P.NUMERO_TESSERA JOIN COPIA C ON P.ISBN = C.ISBN JOIN LIBRO L ON C.ISBN = L.ISBN;

--Utilizzo della vista
SELECT LIBRO_PRESO_IN_PRESTITO, INIZIO_PRESTITO, SCADENZA
FROM PRESTITI_EFFETTUATI
WHERE NUMERO_TESSERA = '12345678';

/*-------------------------------------------------------------------------------------------
Permette al cliente di visualizzare le valutazioni che ha attribuito ai libri letti.
-------------------------------------------------------------------------------------------*/
CREATE OR REPLACE VIEW RECENSIONI_EFFETTUATE AS
SELECT DISTINCT TITOLO AS LIBRO_RECENSITO, VALUTAZIONE, DATA_RECENSIONE AS DATA, NOME_AUTORE, COGNOME_AUTORE, NUMERO_TESSERA
FROM RECENSIONE R JOIN LIBRO L ON R.ISBN = L.ISBN JOIN SCRITTO S ON L.ISBN = S.ISBN JOIN AUTORE A ON S.ISNI = A.ISNI;

--Utilizzo della vista
SELECT LIBRO_RECENSITO, NOME_AUTORE, COGNOME_AUTORE, VALUTAZIONE, DATA
FROM RECENSIONI_EFFETTUATE
WHERE NUMERO_TESSERA = '12345678';

/*--------------------------------------------------------------------------------------------------
Permette al bibliotecario di visualizzare la posizione delle copie dei libri e la loro disponibilità.
Utilizza la function VISUALIZZA_DISPONIBILITA_COPIE.
---------------------------------------------------------------------------------------------------*/
CREATE OR REPLACE VIEW COPIE_DISPONIBILI AS
SELECT DISTINCT L.ISBN, TITOLO, GENERE, VISUALIZZA_NUMERO_COPIE (L.ISBN) AS COPIE_DISPONIBILI, LETTERA_MENSOLA, NUMERO_PIANO
FROM LIBRO L JOIN COPIA C ON L.ISBN = C.ISBN;

--Utilizzo della vista
SELECT * FROM COPIE_DISPONIBILI;

/*---------------------------------------------------------------------------------------------
Permette al direttore di visualizzare gli ordini effettuati dalla biblioteca e la disponibilità
di copie dei libri per controllare eventuali incongruenze.
Utilizza le function VISUALIZZA_ORDINE e VISUALIZZA_DISPONIBILITA_COPIE.
---------------------------------------------------------------------------------------------*/
CREATE OR REPLACE VIEW COPIE_ORDINATE AS
SELECT DISTINCT ISBN, VISUALIZZA_NUMERO_COPIE(ISBN) AS COPIE_DISPONIBILI, VISUALIZZA_ORDINE(ISBN) AS NUMERO_COPIE_ORDINATE
FROM LIBRO;

--Utilizzo della vista
SELECT * FROM COPIE_ORDINATE;