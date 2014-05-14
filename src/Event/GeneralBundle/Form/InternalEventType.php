<?php

namespace Event\GeneralBundle\Form;

use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolverInterface;

class InternalEventType extends AbstractType
{
        /**
     * @param FormBuilderInterface $builder
     * @param array $options
     */
    public function buildForm(FormBuilderInterface $builder, array $options)
    {
        $builder
            ->add('name')
            ->add('date')
            ->add('start')
            ->add('duration')
            ->add('description')
            ->add('tags', 'hidden')
            ->add('status', 'hidden')
        ;
    }
    
    /**
     * @param OptionsResolverInterface $resolver
     */
    public function setDefaultOptions(OptionsResolverInterface $resolver)
    {
        $resolver->setDefaults(array(
            'data_class' => 'Event\GeneralBundle\Entity\InternalEvent'
        ));
    }

    /**
     * @return string
     */
    public function getName()
    {
        return 'event_generalbundle_internalevent';
    }
}
