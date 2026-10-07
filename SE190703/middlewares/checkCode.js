import passport from "passport";
export default function checkCode(req, res, next) {
  const { code } = req.user?.code;
  if (!code) {
    return res.status(401).render("auth/login");
  }
}
