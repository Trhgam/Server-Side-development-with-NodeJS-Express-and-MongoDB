const express = require("express");
const http = require("http");
require("dotenv").config();
const users = require("./routers/user"); // cần import router từ file user.js
// và để dùng được nó thì càn app.use
const fs = require("fs"); //file system module

const app = express();

// buoi 1
// const server = http.createServer((req, res) => {
//   //   res.statusCode = 200;
//   //   res.setHeader("Content-Type", "application/json");
//   //   res.end(JSON.stringify(users));

//   //   const content = fs.readFileSync("index.html");
//   //   res.writeHead(200, { "Content-Type": "text/html" });
//   //   res.end(content);

//   const content = fs.readFileSync("index.html");
//   res.writeHead(200, { "Content-Type": "text/html" });
//   res.end(content);
// });

// server.listen(process.env.PORT || 3000, () => {
//   console.log(
//     "Server is running on http://localhost:" + (process.env.PORT || 3000),
//   );
// });

// buoi 2
app.use(express.json());
// localhost:3000/users/users
app.use("/users", users);
app.listen(process.env.PORT || 3000, () => {
  console.log(
    "Server is running on http://localhost:" + (process.env.PORT || 3000),
  );
});
