import { useEffect } from "react";
import "./App.css";

function App() {
  useEffect(() => {
    async function getData() {
      try {
        await fetch("https://localhost:5000/users", {
          headers: { Authorization: "Bearer TOKEN" }, // reply request
        });
      } catch (error) {
        console.log("Error fetching data:", error);
      }
    }
    getData();
  }, []);

  return <>HAHAHAHAHAHHAHHAHHAHAHH</>;
}

export default App;
