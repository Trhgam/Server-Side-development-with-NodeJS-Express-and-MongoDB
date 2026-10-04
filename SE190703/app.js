import createError from "http-errors";
import express from "express";
import path from "path";
import { fileURLToPath } from "url";
import cookieParser from "cookie-parser";
import logger from "morgan";
import mongoose from "mongoose";
import dotenv from "dotenv";
import session from "express-session";
import Manager from "./models/managers.js";

dotenv.config();

const __filename = fileURLToPath(import.meta.url);
const __dirname = path.dirname(__filename);

const app = express();
app.set("port", process.env.PORT || 3000);

mongoose
  .connect(process.env.MONGODB_URI)
  .then(async () => {
    console.log("[MongoDB] Connected Successfully!");
    try {
      const count = await Manager.countDocuments();
      if (count === 0) {
        await Manager.create({ code: "MGR001", pass: "123456" });
        console.log(
          "[MongoDB] Default manager account created: MGR001 / 123456",
        );
      }
    } catch (e) {
      console.warn("Could not check/create default manager:", e.message);
    }
  })
  .catch((err) => console.error("[MongoDB] Connection Error:", err));

import indexRouter from "./routes/index.js";

app.set("views", path.join(__dirname, "views"));
app.set("view engine", "ejs");

app.use(logger("dev"));
app.use(express.json());
app.use(express.urlencoded({ extended: false }));
app.use(cookieParser());
app.use(
  session({
    secret: "sdn302_lab02",
    resave: false,
    saveUninitialized: false,
    cookie: { maxAge: 24 * 60 * 60 * 1000 },
  }),
);
app.use(express.static(path.join(__dirname, "public")));

app.use("/", indexRouter);

app.use(function (req, res, next) {
  next(createError(404));
});

app.use(function (err, req, res, next) {
  res.locals.message = err.message;
  res.locals.error = req.app.get("env") === "development" ? err : {};
  res.status(err.status || 500);
  res.render("error");
});

export default app;
