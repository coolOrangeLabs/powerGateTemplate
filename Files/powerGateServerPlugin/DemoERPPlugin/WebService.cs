using powerGateServer.SDK;

namespace DemoERPPlugin
{
	[WebServiceData("PGS/ERP", "DemoService")]
	public class DemoErpSystem : WebService
	{
		public DemoErpSystem()
		{
			AddMethod(new Items());
			AddMethod(new BomHeaders());
			AddMethod(new BomRows());
		}
	}
}