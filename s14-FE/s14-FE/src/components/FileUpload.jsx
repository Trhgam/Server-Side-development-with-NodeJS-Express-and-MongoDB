import { useId, useState } from "react";
import axios from "axios";

function FileUpload({ endpoint, multiple = false }) {
  const inputId = useId();
  const [files, setFiles] = useState([]);
  const [uploadedFiles, setUploadedFiles] = useState([]);
  const [uploading, setUploading] = useState(false);
  const [message, setMessage] = useState("");
  const [error, setError] = useState(false);

  async function handleUpload(event) {
    event.preventDefault();
    if (!files.length || uploading) return;

    setUploading(true);
    setMessage("");
    setUploadedFiles([]);
    setError(false);

    const formData = new FormData();
    for (const file of files) {
      formData.append(multiple ? "files" : "file", file, file.name);
    }

    try {
      const { data } = await axios.post(endpoint, formData);
      setUploadedFiles(multiple ? data.files ?? [] : data.file ? [data.file] : []);

      setMessage(multiple ? "Files uploaded successfully." : "File uploaded successfully.");
    } catch (error) {
      setError(true);
      setMessage(
        axios.isAxiosError(error) && !error.response
          ? "Unable to reach the upload server. Check that it is running and CORS allows this app."
          : error.message,
      );
    } finally {
      setUploading(false);
    }
  }

  return (
    <section>
      <h2>{multiple ? "Upload multiple files" : "Upload a file"}</h2>
      <form onSubmit={handleUpload} aria-busy={uploading}>
        <label htmlFor={inputId}>{multiple ? "Choose files" : "Choose a file"}</label>
        <input
          id={inputId}
          name={multiple ? "files" : "file"}
          multiple={multiple}
          type="file"
          required
          disabled={uploading}
          onChange={(event) => {
            setFiles(Array.from(event.target.files ?? []));
            setUploadedFiles([]);
            setMessage("");
            setError(false);
          }}
        />
        <button type="submit" disabled={!files.length || uploading}>
          {uploading ? "Uploading…" : multiple ? "Upload files" : "Upload"}
        </button>
      </form>
      <p
        role="status"
        aria-live="polite"
        className={error ? "error" : "success"}
      >
        {message}
      </p>
      {uploadedFiles.length > 0 && (
        <div>
          <p>Use the complete stored filename below to download:</p>
          <ul>
            {uploadedFiles.map((file) => (
              <li key={file.filename}>
                {file.originalname}: <code>{file.filename}</code>
              </li>
            ))}
          </ul>
        </div>
      )}
    </section>
  );
}

export default FileUpload;
