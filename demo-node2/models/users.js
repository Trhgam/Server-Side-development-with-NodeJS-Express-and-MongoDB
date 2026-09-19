const moogoose = require("mongoose");

const userSchema = new moogoose.Schema({
  // Có 2 cách kahi báo kiểu dữ liệu cho mongoose
  // Dạng 1: khai báo trực tiếp kiểu dữ liệu
  // name: String
  // Dạng 2: khai báo kiểu dữ liệu thông qua object
  // name: {
  //     type: String,
  //     required: true
  // }
  name: { type: String, required: true },
  age: {
    type: Number,
    min: 0,
    max: 120,
  },
  email: {
    type: String,
  },
});
// Để dùng được nó thì phải export ra ngoài
// nhưng cần  model nên là
// model("Tên model", schema) schema là cái đã khai báo và code ở trên á
// viết không cần có s nó tự ánh xạ, nếu có s rồi thì nó ko cần thêm
module.exports = moogoose.model("User", userSchema, "test");

// Mốt code theo MVC
