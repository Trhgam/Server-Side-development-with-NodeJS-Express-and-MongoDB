import jwt from "jsonwebtoken";

export default function checkBearerToken(req, res, next) {
  // 1. Lấy chuỗi header Authorization (có dạng: "Bearer <token>")
  const authHeader = req.headers.authorization;
  const token = authHeader && authHeader.split(" ")[1];

  // 2. Nếu không có token gửi kèm
  if (!token) {
    return res.status(401).json({ error: "Access denied. Token missing." });
  }

  try {
    // 3. Kiểm tra token có đúng secret key và còn hạn không
    const decoded = jwt.verify(token, process.env.JWT_SECRET);
    req.user = decoded; // Lưu thông tin giải mã vào req.user
    return next(); // Hợp lệ thì cho đi tiếp vào API
  } catch (err) {
    return res.status(403).json({ error: "Invalid or expired token." });
  }
}
