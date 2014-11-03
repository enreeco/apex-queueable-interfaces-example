/*
 * Author: Enrico Murru @enreeco
 * Site: http://about.me/enreeco
 */
trigger CaseQueuebleTrigger on Case (after insert, after update) {

    List<Callout__c> calloutsScheduled = new List<Callout__c>();
    for(Integer i = 0; i < Trigger.new.size(); i++){
        if((Trigger.isInsert || 
           Trigger.new[i].Status != Trigger.old[i].Status)
            && Trigger.new[i].Status == 'Closed' )
        {
        	ID jobID = System.enqueueJob(new CaseQueuebleJob(Trigger.new[i]));
        	calloutsScheduled.add(new Callout__c(Job_ID__c = jobID, 
                                                 Case__c = Trigger.new[i].Id,
												Status__c = 'Queued'));
        }
    }
    if(calloutsScheduled.size()>0){
        insert calloutsScheduled;
    }
}