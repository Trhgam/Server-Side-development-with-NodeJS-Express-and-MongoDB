import passport from "passport";
import { Strategy as LocalStrategy } from "passport-local";
import Manager from "../models/managers.js";
import bcrypt from "bcrypt";

passport.use(
  new LocalStrategy(
    {
      usernameField: "code", // mapping với trường "code" trong form đăng nhập
      passwordField: "password", // phảo khai báo để nó không mặc định là "password"
      // nếu thay đổi vị trí thì có được không ?
    },
    async (code, password, done) => {
      try {
        const manager = await Manager.findOne({ code: code }).select(
          "+password",
        ); // select password để lấy ra password và thêm + để lấy ra password đã được ẩn đi trong model

        if (!manager) {
          return done(null, false, { message: "Incorrect code" });
          // tham số thứ 2 là false để báo lỗi, tham số thứ 3 là message lỗi, tham số đầu là null để báo lỗi không có lỗi gì
          // nhưnng nó là câu truy vấn do truy vấn được nên nó ko phải là error
        }

        // check if password is correct
        //  khong dùng bcrypt vì password đã được mã hóa bằng bcrypt trong model, nên khi so sánh thì phải giải mã trước
        // const isMatch = password === manager.pass;
        const isMatch = await bcrypt.compare(password, manager.pass); // so sánh password nhập vào với password trong DB

        if (!isMatch) {
          return done(null, false, { message: "Incorrect password" });
        }

        return done(null, manager);
      } catch (err) {
        return done(err);
      }
    },
  ),
);
// hàm này dùng để lưu thông tin manager vào session,
// khi đăng nhập thành công thì nó sẽ lưu thông tin manager
// vào session để sử dụng cho các lần truy cập tiếp theo
passport.serializeUser((manager, done) => {
  done(null, manager.id); // tự động lấy id của manager để lưu vào session
});

passport.deserializeUser(async (id, done) => {
  // Lấy 'id' từ session (cookie), truy vấn DB
  // Chạy xong, Passport tự động gán kết quả (manager) vào 'req.user' cho các request tiếp theo
  try {
    const manager = await Manager.findById(id);
    done(null, manager);
  } catch (err) {
    done(err);
  }
});
