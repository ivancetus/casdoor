import {useEffect} from "react";
import {useLocation} from "react-router-dom";

export const RedirectFilter = ({children}) => {
  const location = useLocation();
  const sso = process.env.REACT_APP_SSO;

  useEffect(() => {
    if (location.pathname === "/account" && sso && sso !== "") {
      window.location.href = sso;
    }
  }, [location, sso]);

  return children;
};
