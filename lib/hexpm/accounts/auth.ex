defmodule Hexpm.Accounts.Auth do
  import Ecto.Query, only: [from: 2]

  alias Hexpm.Accounts.{Key, User, Users, TOTP, BackupCode}

  def key_auth(user_secret) do
    # Database index lookup on the first part of the key and then
    # secure compare on the second part to avoid timing attacks
    app_secret = Application.get_env(:hexpm, :secret)

    <<first::binary-size(32), second::binary-size(32)>> =
      :crypto.hmac(:sha256, app_secret, user_secret)
      |> Base.encode16(case: :lower)

    result =
      from(k in Key,
           where: k.secret_first == ^first,
           join: u in assoc(k, :user),
           preload: [user: {u, [:emails, :twofactor]}])
      |> Hexpm.Repo.one

    case result do
      nil ->
        :error
      key ->
        if Comeonin.Tools.secure_check(key.secret_second, second) do
          if is_nil(key.revoked_at) do
            {:ok, {key.user, key, find_email(key.user, nil)}}
          else
            :revoked
          end
        else
          :error
        end
    end
  end

  def password_auth(username_or_email, password) do
    user = Users.get(username_or_email, [:emails, :twofactor])
    if user && Comeonin.Bcrypt.checkpw(password, user.password) do
      {:ok, {user, nil, find_email(user, username_or_email)}}
    else
      :error
    end
  end

  def twofactor_auth(user, code, backup_allowed? \\ true) do
    case User.totp(user) do
      %TOTP{} = totp ->
        case TOTP.verify(totp, code) do
          true ->
            {:ok, user}

          false ->
            :error

          {:backupcode, code} ->
            if backup_allowed? && BackupCode.included?(user.twofactor.data["backupcodes"], code) do
              {:backupcode, user, code}
            else
              :error
            end
        end

      :disabled ->
        {:ok, user}
    end
  end

  def gen_password(nil), do: nil
  def gen_password(password), do: Comeonin.Bcrypt.hashpwsalt(password)

  def gen_key do
    :crypto.strong_rand_bytes(16)
    |> Base.encode16(case: :lower)
  end

  defp find_email(user, email) do
    Enum.find(user.emails, &(&1.email == email)) || Enum.find(user.emails, & &1.primary)
  end
end
