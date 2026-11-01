import { BackupExtensionAbility, BundleVersion, fileIo as fs } from '@kit.CoreFileKit';
import { Repository } from '../data/Repository';
import { BackupService } from '../services/BackupService';
import { copy } from '../model/Models';

class BackupResult { type:string='ErrorInfo'; errorCode:number=0; errorInfo:string=''; }
export default class ItemNestBackup extends BackupExtensionAbility {
  async onBackupEx(info:string):Promise<string> {
    const result=new BackupResult();const repository=new Repository();
    try {
      await repository.open(this.context);const path=this.context.filesDir+'/system-backup';if(!fs.accessSync(path))fs.mkdirSync(path);
      const service=new BackupService(this.context,repository);
      await service.archive(copy(repository.data),path+'/current.new.itemnest');
      fs.renameSync(path+'/current.new.itemnest',path+'/current.itemnest');
    } catch(error) {result.errorCode=1;result.errorInfo=(error as Error).message;}
    finally {repository.close();}
    return JSON.stringify(result);
  }
  async onRestoreEx(version:BundleVersion,info:string):Promise<string> {
    const result=new BackupResult();const repository=new Repository();
    const service=new BackupService(this.context,repository);
    try {
      const relative='/system-backup/current.itemnest';
      const candidates=[this.context.backupDir+'/restore'+this.context.filesDir+relative,this.context.backupDir+'/restore/data/storage/el2/base/files'+relative,this.context.backupDir+'/restore/data/storage/el2/base/haps/entry/files'+relative];
      const path=candidates.find((value:string)=>fs.accessSync(value));if(!path)throw new Error('系统恢复文件未找到');
      await repository.open(this.context);
      const preview=await service.readArchive(path);
      await service.restore(preview,true,false);
    } catch(error) {result.errorCode=1;result.errorInfo=(error as Error).message;}
    finally {service.cleanup();repository.close();}
    return JSON.stringify(result);
  }
  async onRelease(scenario:number):Promise<void> {
    const path=this.context.filesDir+'/system-backup';if(fs.accessSync(path))fs.rmdirSync(path);
  }
}
