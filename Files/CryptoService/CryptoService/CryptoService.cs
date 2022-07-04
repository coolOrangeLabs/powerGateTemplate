using System;
using System.Net;
using System.Security;
using System.Security.Cryptography;
using System.Text;

namespace CryptoService
{
    public class CryptoService
    {
        private readonly string SALT = "[B@4$%06b0";
        private readonly int ITERATION_COUNT = 169;
        private readonly String encryptionPassword = "sSV2OwK._-a2-@OnjNvNeVqwUVr";


        /// <summary>
        /// Encrypts a message and also adds the initialization vector in front of the payload
        /// (the vector uses the first 16 bytes) 
        /// </summary>
        /// <param name="raw"></param>
        /// <returns></returns>
        public string Encrypt(string raw)
        {
            if (raw == null)
            {
                return null;
            }

            using (var csp = new AesCryptoServiceProvider()
            {
                Mode = CipherMode.CBC,
                Padding = PaddingMode.PKCS7
            })
            {
                csp.GenerateIV();
                byte[] iv = new byte[16];
                Buffer.BlockCopy(csp.IV, 0, iv, 0, 16);

                ICryptoTransform e = GetCryptoTransform(csp, true, this.encryptionPassword, SALT, iv);
                byte[] inputBuffer = Encoding.UTF8.GetBytes(raw);
                byte[] output = e.TransformFinalBlock(inputBuffer, 0, inputBuffer.Length);

                //prepend the IV as the first 16 bytes
                byte[] finalPayload = new byte[output.Length + 16];
                Buffer.BlockCopy(iv, 0, finalPayload, 0, 16);
                Buffer.BlockCopy(output, 0, finalPayload, 16, output.Length);

                string encrypted = Convert.ToBase64String(finalPayload);

                return encrypted;
            }
        }


        /// <summary>
        /// Decrypts a message with the added initialization vector in front of the payload
        /// (the vector uses the first 16 bytes) 
        /// </summary>
        internal SecureString Decrypt(string encrypted)
        {
            if (encrypted == null)
            {
                return null;
            }

            SecureString ret = null;
            using (var csp = new AesCryptoServiceProvider()
            {
                Mode = CipherMode.CBC,
                Padding = PaddingMode.PKCS7
            })
            {
                byte[] finalPayload = Convert.FromBase64String(encrypted);
                if (finalPayload.Length >= 16)
                {
                    byte[] iv = new byte[16];
                    byte[] input = new byte[finalPayload.Length - 16];

                    Buffer.BlockCopy(finalPayload, 0, iv, 0, 16);
                    Buffer.BlockCopy(finalPayload, 16, input, 0, input.Length);

                    var d = GetCryptoTransform(csp, false, this.encryptionPassword, SALT, iv);

                    byte[] decryptedOutput = d.TransformFinalBlock(input, 0, input.Length);

                    string s = Encoding.UTF8.GetString(decryptedOutput);
                    ret = new NetworkCredential("", s).SecurePassword;
                }
            }
            return ret;
        }


        private ICryptoTransform GetCryptoTransform(AesCryptoServiceProvider csp, bool encrypting, string password, string salt, byte[] initVector)
        {
            var spec = new Rfc2898DeriveBytes(Encoding.UTF8.GetBytes(password), Encoding.UTF8.GetBytes(salt), ITERATION_COUNT);
            //only use 16 bytes for the key
            byte[] key = spec.GetBytes(16);

            csp.IV = initVector;
            csp.Key = key;
            if (encrypting)
            {
                return csp.CreateEncryptor();
            }
            return csp.CreateDecryptor();
        }

    }

}