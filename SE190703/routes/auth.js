import express from "express";
import { getLoginView, postLogin } from "../controllers/auth.js";
import checkPassport from "../middlewares/checkPassport.js";

const router = express.Router();

router.get("/view", getLoginView);
router.post("/view", postLogin);
router.post("/login", checkPassport, postLogin);
router.get("/", (req, res) => res.redirect("/auth/view"));

export default router;
