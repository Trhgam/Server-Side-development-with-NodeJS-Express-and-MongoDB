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
  createAt: {
    type: Date,
    default: Date.now,
    immutable: true, // không thay đổi cái gì đó
  },
});
// Để dùng được nó thì phải export ra ngoài
// nhưng cần  model nên là
// model("Tên model", schema) schema là cái đã khai báo và code ở trên á
// viết không cần có s nó tự ánh xạ, nếu có s rồi thì nó ko cần thêm
module.exports = moogoose.model("User", userSchema, "test");

// Mốt code theo MVC
// Model: là nơi tương tác với db, viết các hàm để thao tác với db
// require: true để bắt buộc phải có value khi insert vào db, nếu ko có thì nó sẽ báo lỗi
// default: có set sẵn value khi ko có value truyền vào
// để trường hợp value undefined, thì nó vẫn qua được require
// còn để null là require sẽ ko qua được, vì null là có value nhưng ko hợp lệ
// undefine là biến được khởi tạo nhưng chưa có giá trị, null là biến được khởi tạo và có giá trị nhưng giá trị đó là null
// select: false là khi query ra thì nó sẽ ko hiện trường đó ra, nhưng vẫn có thể query được, chỉ là ko hiển thị ra thôi
// validate
// imulate: thường dùng cho các trường hợp validate phức tạp hơn, vd như validate email, phone, password, ...
//

// Index: đánh trên field sort search hay truy xuất nhiều, dùng cho trừng hợp email do email ko đc rùng nnhau
// unique: true là ko đc trùng nhau, vd như email, username, phone, ...
