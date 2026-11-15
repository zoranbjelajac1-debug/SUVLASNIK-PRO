# SUVLASNIK PRO 1.1 – ONLINE paket

## Sadržaj
- `index.html` – PWA korisničko sučelje povezano sa Supabase Auth/Database/Storage/RPC
- `config.js` – javni Supabase URL i anon key (popunjava administrator)
- `manifest.json`, `sw.js` – PWA postavke
- `supabase_schema.sql` – početna baza, RLS pravila, privatni storage, glasanje i weighted results RPC
- `supabase/functions/invite-member/index.ts` – Edge Function za pozivanje korisnika; service role ostaje na serveru

## Važno: ovo još nije aktivan online servis
Nije moguće unaprijed povezati aplikaciju s bazom bez Supabase projekta i administratorskih pristupnih podataka. Paket je spreman za konfiguraciju i testiranje, ali sinkronizacija, prijave i pohrana rade tek nakon koraka ispod.

## Postavljanje
1. Kreirajte Supabase projekt.
2. U SQL Editoru izvršite `supabase_schema.sql`.
3. U `buildings` unesite jedan red za zgradu Put Skalica 12, Split; zabilježite njegov UUID.
4. Kreirajte prvog administratora kroz Supabase Auth (Dashboard > Authentication > Users > Add user).
5. Ručno dodajte tog administratora u `members` tablicu s istim auth user UUID-om, building_id, provjerenim imenom i ulogom `admin`.
6. U Supabase Edge Functions postavite `invite-member` iz priložene mape. Provjerite dostupnost standardnih tajni SUPABASE_URL, SUPABASE_ANON_KEY i SUPABASE_SERVICE_ROLE_KEY; service role ključ nikad ne kopirati u frontend.
7. U `config.js` upišite Project URL i anon/public key.
8. Objavite sadržaj na HTTPS hostingu (npr. vlastita domena ili statički hosting). PWA/service worker ne rade punim kapacitetom iz file://.
9. Administrator kroz aplikaciju poziva preostalih 8 suvlasnika e-mailom. Svaki postavlja svoju lozinku kroz pozivnu poveznicu.
10. Unesite udjele tek nakon provjere vjerodostojne evidencije. Zbroj treba odgovarati 100% prema relevantnom dokumentu; nemojte nagađati udjele.

## Sigurnosna i pravna upozorenja
- Testirajte RLS politike s barem dva različita računa prije stvarne uporabe.
- Aplikacija ne prikazuje identitet pojedinačnih glasova drugim suvlasnicima; rezultate prikazuje zbirno ponderirane udjelima. Admin/audit pristup mora biti jasno definiran i pravno opravdan.
- SQL je početna implementacija i mora proći sigurnosni pregled prije produkcije. Posebno testirati Storage RLS, pozivanje korisnika, brisanje/deaktivaciju, zatvaranje glasanja i audit log.
- PDF izvještaj je evidencijski izvještaj iz aplikacije, ne potvrda pravne valjanosti odluke.
- Za formalna glasanja potrebno je provjeriti način sazivanja, dostave, identifikacije, rokove, većinu, udjele, eventualne posebne većine i način potpisivanja/čuvanja odluka.
- Prije stvarnih osobnih podataka pripremiti obavijest o privatnosti, pravnu osnovu, rokove čuvanja, pravila pristupa, sigurnosne kopije i postupak incidenta.
- Ne dijelite service_role ključ, lozinke ni pristupne tokene.

## Funkcije
- E-mail/lozinka prijava i reset lozinke.
- Jedinstveni profil člana i zgrade.
- Sinkronizirani obavijesti, prijave, dokumenti i glasanja.
- Upload PDF/JPG/PNG/WEBP do 20 MB u privatni storage bucket.
- Download preko kratkotrajnih signed URL-ova.
- Evidencija suvlasničkih udjela.
- Jedan glas po članu po glasanju preko RPC-a.
- Rezultati ponderirani udjelima.
- PDF izvještaj rezultata.
- Arhiva dokumenata kategorija odluka i zapisnik.
