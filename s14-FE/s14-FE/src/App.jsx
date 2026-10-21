import FileUpload from "./components/FileUpload.jsx";
import FileDownload from "./components/FileDownload.jsx";
import Layout from "./components/Layout.jsx";

const UPLOAD_URL = "https://localhost:5000/upload";

function App() {
  return (
    <Layout>
      <FileUpload endpoint={`${UPLOAD_URL}/single`} />
      <FileUpload endpoint={`${UPLOAD_URL}/multiple`} multiple />
      <FileDownload endpoint="https://localhost:5000/download" />
    </Layout>
  );
}

export default App;
