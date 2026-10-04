export const requireLogin = (req, res, next) => {
  if (req.session && req.session.manager) {
    return next();
  }
  return res.redirect("/auth/view");
};
