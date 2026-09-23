var express = require("express");
var router = express.Router();
const { getPosts, createPost } = require("../controllers/post");

router.get("/", getPosts);
router.post("/", createPost);

module.exports = router;
