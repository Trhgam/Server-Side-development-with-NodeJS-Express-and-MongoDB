import passport from "passport";
export default function checkPassport(req, res, next) {
  return passport.authenticate(
    "local",
    { session: true },
    (error, manager, info) => {
      if (error) {
        return next(error);
      }
      if (!manager) {
        console.log(
          "--> Đăng nhập ko thành công, code vừa nhập:",
          req.body.code,
        );
        return res.status(401).render("auth/login", {
          error: info?.message || "Login failed",
          code: req.body?.code || "",
        });
      }

      console.log("--> Đăng nhập thành công manager:", manager.code);
      // login ok nó sẽ gọi hàm serializeUser để lưu thông tin manager vào session
      return req.logIn(manager, next); // tham số thứ 2 là next để nó gọi hàm serializeUser để lưu thông tin manager vào session
    },
  )(req, res, next);
}
