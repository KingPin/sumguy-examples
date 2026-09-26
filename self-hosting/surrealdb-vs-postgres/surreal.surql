-- Schema with field-level checks and permissions
DEFINE TABLE person SCHEMAFULL;
DEFINE FIELD name ON person TYPE string;
DEFINE FIELD age ON person TYPE int ASSERT $value >= 0;
DEFINE FIELD email ON person TYPE string PERMISSIONS FOR update NONE;

CREATE person:alice SET name = "Alice", age = 30, email = "alice@example.com";
CREATE person:bob SET name = "Bob", age = 25, email = "bob@example.com";
CREATE person:carol SET name = "Carol", age = 41, email = "carol@example.com";

-- Graph edges
RELATE person:alice->follows->person:bob SET since = time::now();
RELATE person:bob->follows->person:carol SET since = time::now();

SELECT ->follows->person AS following FROM person:alice;
SELECT ->follows->person->follows->person AS network FROM person:alice;

-- Record links
DEFINE TABLE post SCHEMAFULL;
DEFINE FIELD title ON post TYPE string;
DEFINE FIELD author ON post TYPE record<person>;

CREATE post:p1 SET title = "Hello SurrealDB", author = person:alice;
SELECT title, author.name FROM post;

-- Full-text search (3.x keyword is FULLTEXT)
DEFINE ANALYZER simple TOKENIZERS class FILTERS lowercase, ascii;
DEFINE INDEX article_body ON post FIELDS title FULLTEXT ANALYZER simple BM25 HIGHLIGHTS;

CREATE post:s1 SET title = "SurrealDB search test", author = person:alice;
SELECT * FROM post WHERE title @@ "search";
