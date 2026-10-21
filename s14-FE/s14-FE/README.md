# File uploads

Run `npm install` and `npm run dev` to start the React app.

The page includes single-file and multiple-file upload forms using Axios:

- `http://localhost:5000/upload/single`: multipart field `file`.
- `http://localhost:5000/upload/multiple`: repeated multipart field `files`.

Each file includes its original filename. The browser sets the multipart boundary.
The backend must accept these fields and allow the frontend origin through CORS.
Any successful HTTP response (2xx) is shown as a successful upload.

`src/components/Layout.jsx` contains the page layout. The reusable
`src/components/FileUpload.jsx` accepts `endpoint` and `multiple` props.
Configure the endpoint URLs in `src/App.jsx` to match your backend.

Enter a filename and click the Download button below the upload forms.
It uses Axios to fetch a blob from `http://localhost:5000/download/:filename`,
with the filename URL-encoded, and saves it using the entered filename.
The download endpoint is configured in `src/App.jsx`.

Run `npm run lint` and `npm run build` to check the project.
