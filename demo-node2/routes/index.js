var express = require("express");
var router = express.Router();
var usersRouter = require("./users");
var postsRouter = require("./posts");
const productsRouter = require("./products");

router.use("/users", usersRouter);
router.use("/posts", postsRouter);
router.use("/products", productsRouter);

/* GET home page. */
router.get("", function (req, res, next) {
  res.render("index", { title: "Express" });
});

module.exports = router;
