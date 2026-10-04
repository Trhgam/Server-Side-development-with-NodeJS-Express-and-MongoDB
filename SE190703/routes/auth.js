import express from "express";
import { getLoginView, postLogin } from "../controllers/auth.js";

const router = express.Router();

router.get("/view", getLoginView);
router.post("/view", postLogin);
router.post("/login", postLogin);
router.get("/", (req, res) => res.redirect("/auth/view"));

export default router;
