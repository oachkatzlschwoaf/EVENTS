<?php

namespace Event\GeneralBundle\Form;

use Symfony\Component\Form\AbstractType;
use Symfony\Component\Form\FormBuilderInterface;
use Symfony\Component\OptionsResolver\OptionsResolverInterface;

class ProviderEventType extends AbstractType
{
        /**
     * @param FormBuilderInterface $builder
     * @param array $options
     */
    public function buildForm(FormBuilderInterface $builder, array $options)
    {
        $builder
            ->add('name')
            ->add('providerId', 'hidden')
            ->add('date')
            ->add('start')
            ->add('duration')
            ->add('description')
            ->add('place', 'hidden')
            ->add('place_text', 'hidden')
            ->add('status', 'hidden')
            ->add('provider', 'hidden')
        ;
    }
    
    /**
     * @param OptionsResolverInterface $resolver
     */
    public function setDefaultOptions(OptionsResolverInterface $resolver)
    {
        $resolver->setDefaults(array(
            'data_class' => 'Event\GeneralBundle\Entity\ProviderEvent'
        ));
    }

    /**
     * @return string
     */
    public function getName()
    {
        return 'event_generalbundle_providerevent';
    }
}
