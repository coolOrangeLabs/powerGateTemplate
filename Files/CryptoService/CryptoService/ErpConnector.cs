
using powerGate.Erp.Client;
using System;
using System.Net;
using System.Net.Http.Headers;
using System.Security;
using System.Text;

namespace CryptoService
{
    public class ErpConnector
    {
        private readonly string userName;
        private readonly string encryptedPassword;
        private readonly Action<object> onConnectCallback;


        public ErpConnector(string userName, string encryptedPassword, Action<object> onConnect)
        {
            this.userName = userName;
            this.encryptedPassword = encryptedPassword;
            this.onConnectCallback = onConnect;
        }


        public void OnConnect(object settings)
        {
            this.onConnectCallback(settings);

            if (!(settings is ErpClientSettings clientSettings))
            {
                throw new Exception($"{nameof(settings)} must be of type {nameof(ErpClientSettings)}");
            }

            CryptoService cryptoService = new CryptoService();
            SecureString decryptedPassword = cryptoService.Decrypt(this.encryptedPassword);
            if (decryptedPassword == null)
            {
                throw new Exception("Invalid password");
            }

            clientSettings.BeforeRequest = (message =>
            {
                string authParameter = CreateAuthParameter(this.userName, decryptedPassword);
                message.Headers.Authorization = new AuthenticationHeaderValue("Basic", authParameter);
            }) + clientSettings.BeforeRequest;
        }


        private string CreateAuthParameter(string userName, SecureString decryptedPassword)
        {
            NetworkCredential credential = new NetworkCredential(userName, decryptedPassword);
            string credentials = string.Join(":", credential.UserName, credential.Password);
            Encoding encoding = Encoding.GetEncoding("ISO-8859-1");
            byte[] plainTextBytes = encoding.GetBytes(credentials);
            return Convert.ToBase64String(plainTextBytes);
        }

    }
}
