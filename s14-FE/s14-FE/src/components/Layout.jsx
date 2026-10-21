function Layout({ children }) {
  return (
    <main>
      <h1>File uploads</h1>
      <div className="upload-forms">{children}</div>
    </main>
  );
}

export default Layout;
