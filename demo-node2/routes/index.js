var express = require("express");
var router = express.Router();
var usersRouter = require("./users");
var postsRouter = require("./posts");
const products = require("./products");

router.use("/users", usersRouter);
router.use("/posts", postsRouter); //
router.use("/products", products); //

/* GET home page. */
router.get("", function (req, res, next) {
  res.render("index", { title: "Express" });
});

module.exports = router;
