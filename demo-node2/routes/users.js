var express = require("express");
var router = express.Router();
const user = [];

const { body, validationResult } = require("express-validator");
const validates = [
  body("name").notEmpty().withMessage("Name is required"),
  body("email").isEmail().withMessage("Invalid email address"),
  (req, res, next) => {
    const errors = validationResult(req);
    if (!errors.isEmpty()) {
      return res.status(400).json({ errors: errors.array() });
    }
    next();
  },
];
/* GET users listing. */
router.get("/", function (req, res, next) {
  try {
    res.send("respond with a resource");
  } catch (err) {
    console.log(err);
    next(err);
  }
});
router.post("/", validates, function (req, res, next) {
  try {
    const body = {
      name: req.body.name,
      email: req.body.email,
    };
    user.push(body);
    res.status(201).json({
      message: "User created successfully",
    });
  } catch (err) {
    console.log(err);
    next(err);
  }
});

module.exports = router;
