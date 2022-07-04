using System;
using System.IdentityModel.Selectors;
using System.IdentityModel.Tokens;

namespace ErpServices.Services
{
    // This class is automatically called on each request for this wcf service
    // The configuration is inside powerGateServer.exe.config
    public class UserAuthentication : UserNamePasswordValidator
    {
        public override void Validate(string userName, string password)
        {
            if (userName == null || null == password)
                throw new ArgumentNullException();
            if (userName != "coolOrange" || password != "coolOrange")
                throw new SecurityTokenException("Unknown Username or Password");
        }
    }
}