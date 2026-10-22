
const express = require("express");

const app = express();
const PORT = process.env.PORT || 3000;

app.use(express.json());

app.get("/", (req, res) => {
  res.json({
    message: "Hello from my production API!",
    environment: process.env.NODE_ENV || "development"
  });
});

app.get("/health", (req, res) => {
  res.status(200).json({ status: "ok" });
});

app.get("/version", (req, res) => {
  res.json({
    version: "1.1.0",
    message: "My first CI/CD deployment!"
  });
});
app.listen(PORT, "0.0.0.0", () => {
  console.log(`API listening on port ${PORT}`);
});
