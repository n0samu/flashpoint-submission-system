package main

import (
	"context"
	"encoding/json"
	"fmt"
	"github.com/gorilla/mux"
	"net/http"
)

func (a *App) handleRequests(srv *http.Server, router *mux.Router) {
	// oauth
	router.Handle("/auth", http.HandlerFunc(a.HandleDiscordAuth)).Methods("GET")
	router.Handle("/auth/callback", http.HandlerFunc(a.HandleDiscordCallback)).Methods("GET")

	//home
	router.Handle("/home", http.HandlerFunc(a.UserAuth(a.HandleHomePage))).Methods("GET")
	srv.ListenAndServe()
}

func (a *App) HandleHomePage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	userID := UserIDFromContext(ctx)

	discordUser, err := a.GetDiscordUser(userID)
	if err != nil {
		LogCtx(ctx).Error(err)
		http.Error(w, "failed to load user data", http.StatusInternalServerError)
		return
	}
	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	w.Write([]byte(fmt.Sprintf("<html>hello %s, this is your home now. <img src='https://cdn.discordapp.com/avatars/%s/%s'></html>", discordUser.Username, discordUser.ID, discordUser.Avatar)))
}

func (a *App) HandleDiscordAuth(w http.ResponseWriter, r *http.Request) {
	http.Redirect(w, r, a.conf.OauthConf.AuthCodeURL(state), http.StatusTemporaryRedirect)
}

type DiscordUserResponse struct {
	ID            string `json:"id"`
	Username      string `json:"username"`
	Avatar        string `json:"avatar"`
	Discriminator string `json:"discriminator"`
	PublicFlags   int    `json:"public_flags"`
	Flags         int    `json:"flags"`
	Locale        string `json:"locale"`
	MFAEnabled    bool   `json:"mfa_enabled"`
}

// TODO provide real, secure oauth state
var state = "random"

func (a *App) HandleDiscordCallback(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()

	// verify state
	if r.FormValue("state") != state {
		http.Error(w, "state does not match", http.StatusBadRequest)
		return
	}

	// obtain token
	token, err := a.conf.OauthConf.Exchange(context.Background(), r.FormValue("code"))

	if err != nil {
		LogCtx(ctx).Error(err)
		http.Error(w, "failed to obtain discord auth token", http.StatusInternalServerError)
		return
	}

	// obtain user data
	resp, err := a.conf.OauthConf.Client(context.Background(), token).Get("https://discordapp.com/api/users/@me")

	if err != nil || resp.StatusCode != 200 {
		http.Error(w, "failed to obtain discord user data", http.StatusInternalServerError)
		return
	}
	defer resp.Body.Close()

	var discordUser DiscordUserResponse
	err = json.NewDecoder(resp.Body).Decode(&discordUser)
	if err != nil {
		LogCtx(ctx).Error(err)
		http.Error(w, "failed to parse discord response", http.StatusInternalServerError)
		return
	}
	LogCtx(ctx).Infof("%+v\n", discordUser)

	// save discord user data
	if err := a.StoreDiscordUser(&discordUser); err != nil {
		LogCtx(ctx).Error(err)
		http.Error(w, "failed to store discord user", http.StatusInternalServerError)
		return
	}

	// create cookie and save session
	authToken, err := CreateAuthToken()
	if err != nil {
		LogCtx(ctx).Error(err)
		http.Error(w, "failed to generate auth token", http.StatusInternalServerError)
		return
	}
	if err := SetSecureCookie(w, Cookies.Login, mapAuthToken(authToken)); err != nil {
		LogCtx(ctx).Error(err)
		http.Error(w, "failed to set cookie", http.StatusInternalServerError)
		return
	}

	if err = a.StoreSession(authToken.Secret, discordUser.ID); err != nil {
		LogCtx(ctx).Error(err)
		http.Error(w, "failed to store session", http.StatusInternalServerError)
	}

	w.Write([]byte("you are now logged it, pretty cool isn't it"))
}
