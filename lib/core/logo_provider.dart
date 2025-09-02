
/// Tất cả logo có sẵn trong assets/logos/ (tự động từ cryptocurrency-icons repo)
const Set<String> kLocalLogoKeys = {
  '\$pac','0xbtc','1inch','2give','aave','abt','act','actn','ada','add','adx','ae','aeon','aeur','agi','agrs','aion','algo','amb','amp','ampl','ankr','ant','ape','apex','appc','ardr','arg','ark','arn','arnx','ary','ast','atlas','atm','atom','audr','aury','auto','avax','aywa','bab','bal','band','bat','bay','bcbc','bcc','bcd','bch','bcn','bco','bcpt','bdl','beam','bela','bix','blcn','blk','block','blz','bnb','bnt','bnty','booty','bos','bpt','bq','bqx','brd','bsd','bsv','btc','btcd','btch','btcp','btcz','btdx','btg','btm','bts','btt','btx','burst','buzz','bze','call','cc','cdn','cdt','cenz','chain','chat','chips','cix','clam','cloak','cmm','cmt','cnd','cnx','cny','cob','colx','coqui','cred','crpt','crw','cs','ctr','ctxc','cvc','cvt','cxo','cyc','dai','dash','dat','data','dbc','dcn','dcr','deez','dent','dew','dgb','dgd','dlt','dnr','dock','doge','dot','drgn','drop','dta','dth','dtr','ebst','eca','edg','edo','edoge','ela','elf','elix','ella','eos','eql','equa','etc','eth','ethos','etn','etp','eur','evx','exmo','exp','fair','fct','fida','fil','fldc','flo','flux','fsn','ftc','fuel','fun','game','gas','gbp','gbx','gel','gem','gno','gnt','gold','grc','grin','grs','gsc','gto','gup','gusd','gvt','gxs','hbar','hight','hsr','html','huc','hush','icn','icx','ignis','ilk','ink','ins','ion','iop','iost','iotx','iq','itc','jpy','kcs','kin','kmd','knc','krb','lbc','lend','leo','link','lkk','loom','lpt','lrc','lsk','ltc','lun','maid','mana','matic','max','mcap','mco','mda','mds','med','meetone','mft','miota','mkr','mln','mnx','mnz','moac','mod','mona','msr','mth','mtl','music','mzc','nano','nas','nav','ncash','ndz','nebl','neo','neos','neu','nexo','ngc','nio','nlc2','nlg','nmr','npxs','nuls','nxs','nxt','oax','ocean','ok','omg','omni','ong','ont','oot','ost','ox','oxt','part','pasl','pax','pay','payx','pink','pirl','pivx','plr','poa','poe','polis','poly','pot','powr','ppc','ppp','ppt','prc','pungo','pura','qash','qiwi','qlc','qrl','qsp','qtum','r','rads','rap','rcn','rdd','ren','rep','req','rhoc','ric','rise','rlc','rpx','rub','rvn','ryo','safe','safemoon','sai','salt','san','sand','sbd','sberbank','sc','ser','shift','sib','sin','skl','sky','slr','sls','smart','sngls','snm','snt','snx','soc','sol','spacehbit','spank','sphtx','srn','stak','start','steem','storj','storm','stox','stq','strat','stx','sub','sumo','sushi','sys','taas','tau','tbx','tel','ten','tern','tgch','theta','tix','tkn','tks','tnb','tnc','tnt','tomo','tpay','trig','trtl','trx','tusd','tzc','ubq','uma','uni','unity','usd','usdc','usdt','utk','veri','vet','via','vib','vibe','vivo','vrc','vrsc','vtc','vtho','wabi','wan','waves','wax','wbtc','wgr','wicc','wings','wpr','wtc','x','xas','xbc','xbp','xby','xcp','xdn','xem','xin','xlm','xmcc','xmg','xmo','xmr','xmy','xp','xpa','xpm','xpr','xrp','xsg','xtz','xuc','xvc','xvg','xzc','yfi','yoyow','zcl','zec','zel','zen','zest','zil','zilla','zrx'
};

/// Một số alias ticker -> key logo (đổi tên/viết tắt khác)
const Map<String, String> kSymbolAliases = {
  'polygon': 'matic',
  'pol': 'matic',
  'xno': 'nano',
  '1inch': '1inch',
  '1000shib': 'shib',
  '1000sats': 'btc', // sats = satoshi = bitcoin
  '1000cat': 'cat',
  '1000cheems': 'doge', // cheems variant of doge
  '1mbabydoge': 'doge',
  'wbtc': 'btc',
  'eth2': 'eth',
  'adadown': 'ada',
  'adaup': 'ada',
  'aavedown': 'aave',
  'aaveup': 'aave',
  '1inchdown': '1inch',
  '1inchup': '1inch',
  'agix': 'agi', // SingularityNET rebrand
  'alpaca': 'alpaca',
  'alice': 'alice',
  'akro': 'akro',
  'alcx': 'alcx',
  'alpha': 'alpha',
  'alpine': 'alpine',
  'alt': 'alt',
  'bnbdown': 'bnb',
  'bnbup': 'bnb',
  'btcdown': 'btc',
  'btcup': 'btc',
  'ethdown': 'eth',
  'ethup': 'eth',
  'ltcdown': 'ltc',
  'ltcup': 'ltc',
  'xrpdown': 'xrp',
  'xrpup': 'xrp',
  'dotdown': 'dot',
  'dotup': 'dot',
  'linkdown': 'link',
  'linkup': 'link',
  'trxdown': 'trx',
  'trxup': 'trx',
  'eosdown': 'eos',
  'eosup': 'eos',
};

/// Subset of symbols whose bundled asset is PNG (no SVG available in assets/)
const Set<String> kLocalPngKeys = {
  '1000cat',
  '1000cheems',
  '1000sats',
  '1inchdown',
  '1inchup',
  '1mbabydoge',
  'a',
  'a2z',
  'aavedown',
  'aaveup',
  'aca',
  'ace',
  'ach',
  'acm',
  'acx',
  'adadown',
  'adaup',
  'aergo',
  'aevo',
  'agix',
  'agld',
  'ai',
  'aixbt',
  'akro',
  'alcx',
  'alice',
  'alpaca',
  'alpha',
  'alpine',
  'alt',
};

String normalizeSymbol(String base) {
  final s = base.toLowerCase();
  return kSymbolAliases[s] ?? s;
}

/// Trả về path asset nếu có trong bundle, ngược lại null.
String? localLogoAsset(String base) {
  final key = normalizeSymbol(base);
  // Prefer PNG when the asset only exists as PNG in bundle
  if (kLocalPngKeys.contains(key)) {
    return 'assets/logos/$key.png';
  }
  if (kLocalLogoKeys.contains(key)) {
    // Default to SVG for the majority of icons present as SVG
    return 'assets/logos/$key.svg';
  }
  // Nếu không nằm trong danh sách asset nội bộ, trả về null để dùng CDN/fallback
  // Tránh trả về đường dẫn PNG không tồn tại gây lỗi "Unable to load asset"
  return null;
}

/// URL CDN cho PNG 128px từ repo spothq/cryptocurrency-icons (MIT)
/// Ví dụ: https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/btc.png
String remotePngUrl(String base) {
  final key = normalizeSymbol(base);
  return 'https://cdn.jsdelivr.net/gh/spothq/cryptocurrency-icons@master/128/color/$key.png';
}
