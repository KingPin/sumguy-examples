const express = require("express");
const app = express();
app.get("/", (req, res) => res.send("hello\n"));
app.listen(3000, () => console.log("listening on 3000"));
