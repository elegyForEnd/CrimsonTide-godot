from pathlib import Path
import importlib.util,json,unittest
spec=importlib.util.spec_from_file_location('server_app',Path('server/app.py'))
module=importlib.util.module_from_spec(spec);spec.loader.exec_module(module)
class AttributeCloudTests(unittest.TestCase):
    def setUp(self):
        self.profile={'version':1,'name':'Watcher','coins':0,'xp':180,'runs':0,'extracts':0,'hero':0,'gear':0,'best':0,'talents':[0,0,0],'pocket':{},'bags':[]}
    def test_legacy(self): module.validate_profile(self.profile)
    def test_json_attributes(self):
        self.profile['attributes']={'vigor':13,'intelligence':13}
        module.validate_profile(json.loads(json.dumps(self.profile)))
    def test_excess_points(self):
        self.profile['attributes']={'vigor':17}
        with self.assertRaises(module.ApiError): module.validate_profile(self.profile)
    def test_invalid_values(self):
        for value in [True,'15',9,100,10.5,[],None]:
            self.profile['attributes']={'strength':value}
            with self.assertRaises(module.ApiError): module.validate_profile(self.profile)
    def test_unknown_key(self):
        self.profile['attributes']={'luck':15}
        with self.assertRaises(module.ApiError): module.validate_profile(self.profile)
if __name__=='__main__': unittest.main()
