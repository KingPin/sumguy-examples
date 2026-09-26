CREATE TABLE person (id serial PRIMARY KEY, name text, age int);
CREATE TABLE follows (
  follower_id int REFERENCES person(id),
  followee_id int REFERENCES person(id),
  since timestamptz DEFAULT now(),
  PRIMARY KEY (follower_id, followee_id)
);

INSERT INTO person (name, age) VALUES ('Alice', 30), ('Bob', 25), ('Carol', 41);
INSERT INTO follows (follower_id, followee_id) VALUES (1, 2), (2, 3);

-- Who does Alice follow (one hop)
SELECT p.name
FROM follows f
JOIN person p ON p.id = f.followee_id
WHERE f.follower_id = 1;

-- Friends of friends (two hops) with a recursive CTE
WITH RECURSIVE network AS (
  SELECT followee_id, 1 AS depth FROM follows WHERE follower_id = 1
  UNION ALL
  SELECT f.followee_id, n.depth + 1
  FROM follows f JOIN network n ON f.follower_id = n.followee_id
  WHERE n.depth < 2
)
SELECT p.name, n.depth FROM network n JOIN person p ON p.id = n.followee_id;

-- Full-text search
CREATE TABLE post (id serial PRIMARY KEY, title text);
ALTER TABLE post ADD COLUMN search_vec tsvector
  GENERATED ALWAYS AS (to_tsvector('english', title)) STORED;
CREATE INDEX post_search_idx ON post USING gin(search_vec);

INSERT INTO post (title) VALUES ('Hello Postgres'), ('Postgres search test');
SELECT * FROM post WHERE search_vec @@ plainto_tsquery('english', 'search');
