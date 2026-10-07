import bcrypt from "bcrypt";
import jwt from "jsonwebtoken";
import Manager from "../models/managers.js";

export async function login(req, res, next) {
  const { code, password } = req.body || {};

  try {
    const manager = await Manager.findOne({
      code: code?.trim(),
    }).select("+pass");

    if (!manager || !(await bcrypt.compare(password, manager.pass))) {
      return res.status(401).json({
        error: "Invalid code or password.",
      });
    }

    const token = jwt.sign({ code: manager.code }, process.env.JWT_SECRET, {
      algorithm: "HS256",
      expiresIn: "1h",
      subject: manager.id,
    });

    return res.json({ token });
  } catch (error) {
    return next(error);
  }
}

export function profile(req, res) {
  return res.json({
    user: "123",
  });
}
