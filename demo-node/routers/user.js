const express = require("express");

const router = express.Router();

let users = [
  { name: "Gam", email: "honggamdx2@gmail.com" },
  { name: "John", email: "john@example.com" },
];

// khi gọi router.get(), tham số 1 là đường dẫn, tham số 2 là callback function request và response
router.get("/", (req, res) => {
  res.json(users);
});
//localhost:3000/users/:id
router.get("/:id", (req, res) => {
  const userId = parseInt(req.params.id);
  const user = users.find((u) => u.id === userId);
  if (!user) {
    return res.status(404).json({ message: "User not found" });
  }
  res.json(user);
});
module.exports = router;
