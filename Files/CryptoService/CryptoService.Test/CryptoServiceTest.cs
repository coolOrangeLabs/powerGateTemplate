using System.Net;
using Microsoft.VisualStudio.TestTools.UnitTesting;

namespace CryptoService.Test
{
    [TestClass]
    public class CryptoServiceTest
    {
        [TestMethod]
        public void TestCryptoService()
        {
            AssertCorrectEncryption("mein super geheimes password mit vielen sonderzeichen 249*/42134/@@324§$§");
            AssertCorrectEncryption("a");
            AssertCorrectEncryption("");

            CryptoService cryptoService = new CryptoService();
            string encrypted = cryptoService.Encrypt(null);
            Assert.AreEqual(null, encrypted);
            Assert.AreEqual(null, cryptoService.Decrypt(encrypted));
        }


        private void AssertCorrectEncryption(string text)
        {
            CryptoService cryptoService = new CryptoService();
            string encrypted = cryptoService.Encrypt(text);
            Assert.AreNotEqual(text, encrypted);
            string normalString = new NetworkCredential("", cryptoService.Decrypt(encrypted)).Password;
            Assert.AreEqual(text, normalString);
        }
    }
}
