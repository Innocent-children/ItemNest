import { FormExtensionAbility, formBindingData } from '@kit.FormKit';
import { Want } from '@kit.AbilityKit';
import { CardService } from '../services/CardService';

export default class ItemNestForm extends FormExtensionAbility {
  onAddForm(want:Want):formBindingData.FormBindingData {
    const id=String(want.parameters?.['ohos.extra.param.key.form_identity']??'');
    const dimension=Number(want.parameters?.['ohos.extra.param.key.form_dimension']??2);
    const name=String(want.parameters?.['ohos.extra.param.key.form_name']??'NestCompact');
    const content=CardService.initial(dimension,name);
    if(id)CardService.update(this.context,id,dimension,name).catch(()=>{});
    return formBindingData.createFormBindingData(content);
  }
  onUpdateForm(id:string):void { CardService.update(this.context,id).catch(()=>{}); }
}
