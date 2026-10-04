import Manager from "../models/managers.js";

export const getLoginView = (req, res) => {
  if (req.session && req.session.manager) {
    return res.redirect("/admin/products");
  }
  res.render("auth/login", {
    error: null,
    code: "",
  });
};

export const postLogin = async (req, res) => {
  try {
    const code = (req.body.code || "").trim();
    const password = (req.body.password || req.body.pass || "").trim();

    if (!code || !password) {
      return res.render("auth/login", {
        error: "Please enter both Manager Code and Password!",
        code,
      });
    }

    const manager = await Manager.findOne({ code, pass: password });

    if (!manager) {
      return res.render("auth/login", {
        error: "Invalid Manager Code or Password!",
        code,
      });
    }

    req.session.manager = {
      id: manager._id,
      code: manager.code,
    };

    return res.redirect("/admin/products");
  } catch (error) {
    console.error("Login error:", error);
    return res.render("auth/login", {
      error: "An internal server error occurred. Please try again.",
      code: req.body.code || "",
    });
  }
};
