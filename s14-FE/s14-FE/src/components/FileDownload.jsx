import { useId, useState } from "react";
import axios from "axios";

function FileDownload({ endpoint }) {
  const inputId = useId();
  const [filename, setFilename] = useState("");
  const [downloading, setDownloading] = useState(false);

  async function handleDownload(event) {
    event.preventDefault();
    const requestedFilename = filename.trim();
    if (!requestedFilename || downloading) return;

    setDownloading(true);

    try {
      const response = await axios.get(
        `${endpoint}/${encodeURIComponent(requestedFilename)}`,
        { responseType: "blob" },
      );
      const url = URL.createObjectURL(response.data);
      const link = document.createElement("a");
      link.href = url;
      link.download = requestedFilename;
      document.body.appendChild(link);
      link.click();
      link.remove();
    } catch (error) {
      console(error);
    } finally {
      setDownloading(false);
    }
  }

  return (
    <section aria-busy={downloading}>
      <h2>Download a file</h2>
      <form onSubmit={handleDownload}>
        <label htmlFor={inputId}>Filename</label>
        <input
          id={inputId}
          type="text"
          value={filename}
          placeholder="example.pdf"
          required
          disabled={downloading}
          onChange={(event) => {
            setFilename(event.target.value);
          }}
        />
        <button type="submit" disabled={downloading || !filename.trim()}>
          {downloading ? "Downloading…" : "Download"}
        </button>
      </form>
    </section>
  );
}

export default FileDownload;
